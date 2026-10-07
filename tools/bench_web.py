#!/usr/bin/env python3
"""Frame rate of the web build in headless Chromium (software WebGL, so the
numbers are much lower than on real hardware: compare runs, don't read them
as device fps).

    python3 tools/bench_web.py game/build/web [phone|pc|all] [seconds] [query...]

Serves the build on a local port, opens it with ?bench=late (a throwaway
busy save, see scripts/util/perf_probe.gd) and reads window.coralightPerf.
"phone" is a 390x844 touch screen at 3x pixels (the shell caps it at 2x)
with the CPU slowed 4x; "pc" is 1920x1080.
"""
import functools
import http.server
import json
import socketserver
import sys
import threading
import time

from playwright.sync_api import sync_playwright

PROFILES = {
    "phone": dict(viewport={"width": 390, "height": 844}, device_scale_factor=3, is_mobile=True, has_touch=True, throttle=4,
                  user_agent="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36"),
    "pc": dict(viewport={"width": 1920, "height": 1080}, device_scale_factor=1, is_mobile=False, has_touch=False, throttle=1),
}


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def serve(folder):
    Quiet.extensions_map[".wasm"] = "application/wasm"
    handler = functools.partial(Quiet, directory=folder)
    httpd = socketserver.ThreadingTCPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def run(folder, which, seconds, queries):
    httpd = serve(folder)
    port = httpd.server_address[1]
    results = []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--disable-gpu-vsync",
                                          "--disable-frame-rate-limit"])
        for name in (["phone", "pc"] if which == "all" else [which]):
            prof = dict(PROFILES[name])
            throttle = prof.pop("throttle")
            for q in queries:
                ctx = browser.new_context(**prof)
                page = ctx.new_page()
                errors = []
                page.on("pageerror", lambda e: errors.append(str(e)))
                if throttle > 1:
                    cdp = ctx.new_cdp_session(page)
                    cdp.send("Emulation.setCPUThrottlingRate", {"rate": throttle})
                page.goto("http://127.0.0.1:%d/index.html?%s" % (port, q))
                t0 = time.time()
                page.wait_for_function("window.coralightPerf && window.coralightPerf.history.length >= 3", timeout=240000)
                warm = time.time() - t0
                time.sleep(seconds)
                perf = page.evaluate("window.coralightPerf")
                hist = perf["history"][-int(seconds):]
                fps = sum(hist) / len(hist)
                row = {"profile": name, "query": q, "fps": round(fps, 1), "cpu_ms": perf["cpu_ms"], "busy_ms": perf.get("busy_ms"), "level": perf.get("level"),
                       "worst_ms": perf["worst_ms"], "load_s": round(warm, 1), "errors": errors[:3]}
                results.append(row)
                print(json.dumps(row), flush=True)
                page.screenshot(path="/tmp/claude-0/bench_%s_%s.png" % (name, q.replace("&", "_").replace("=", "")))
                ctx.close()
        browser.close()
    httpd.shutdown()
    return results


if __name__ == "__main__":
    folder = sys.argv[1]
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    seconds = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    queries = sys.argv[4:] or ["bench=late"]
    run(folder, which, seconds, queries)
