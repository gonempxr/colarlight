"""Soundtrack for the promo video, synthesized from scratch (no samples, so
no licence questions): a sad 'wah-wah' intro, an upbeat groove from the
upgrade on, a big chord on the end card, plus sound effects placed at the
events the scene reports (timeline.js sfxEvents).

    write_track(path, events, t0, dur, timeline)
"""
import math
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
RNG = np.random.default_rng(7)


def note(n):  # MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def t_(d):
    return np.arange(int(d * SR)) / SR


def lp(x, f, order=2):
    b, a = butter(order, min(0.99, f / (SR / 2)))
    return lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = butter(order, min(0.99, f / (SR / 2)), btype="high")
    return lfilter(b, a, x)


def bp(x, f0, f1):
    b, a = butter(2, [max(1e-4, f0 / (SR / 2)), min(0.99, f1 / (SR / 2))], btype="band")
    return lfilter(b, a, x)


def env(n, a=0.005, d=0.2, s=0.0, r=0.05, hold=None):
    """Attack, exponential decay towards s, release at the end."""
    tt = np.arange(n) / SR
    e = np.where(tt < a, tt / max(a, 1e-6), s + (1 - s) * np.exp(-(tt - a) / max(d, 1e-6)))
    rn = int(r * SR)
    if rn and rn < n:
        e[-rn:] *= np.linspace(1, 0, rn)
    return e


def osc(f, d, kind="sine", ph=0.0):
    tt = t_(d)
    if callable(f):
        phase = 2 * np.pi * np.cumsum(f(tt)) / SR + ph
    else:
        phase = 2 * np.pi * f * tt + ph
    if kind == "sine":
        return np.sin(phase)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if kind == "square":
        # band-limited-ish square: a few odd harmonics
        return sum(np.sin(phase * k) / k for k in (1, 3, 5, 7, 9)) * 4 / np.pi * 0.8
    if kind == "saw":
        return sum(np.sin(phase * k) * (1 if k % 2 else -1) / k for k in range(1, 12)) * 2 / np.pi * 0.7
    raise ValueError(kind)


def noise(d):
    return RNG.uniform(-1, 1, int(d * SR))


class Mix:
    def __init__(self, dur):
        self.n = int(dur * SR) + SR
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)

    def add(self, at, sig, gain=1.0, pan=0.0):
        i = int(round(at * SR))
        if i >= self.n or len(sig) == 0:
            return
        if i < 0:
            sig = sig[-i:]
            i = 0
        sig = sig[: self.n - i]
        gl = gain * math.cos((pan + 1) * math.pi / 4) * math.sqrt(2)
        gr = gain * math.sin((pan + 1) * math.pi / 4) * math.sqrt(2)
        self.L[i:i + len(sig)] += sig * gl
        self.R[i:i + len(sig)] += sig * gr


# ------------------------------------------------------------------ instruments
def kick():
    d = 0.35
    f = lambda tt: 45 + 110 * np.exp(-tt * 28)
    return osc(f, d) * env(int(d * SR), 0.001, 0.12) * 1.1


def snare():
    d = 0.22
    n = bp(noise(d), 1200, 9000) * env(int(d * SR), 0.001, 0.07)
    tone = osc(190, d, "tri") * env(int(d * SR), 0.001, 0.05)
    return n * 0.7 + tone * 0.5


def hat(open_=False):
    d = 0.25 if open_ else 0.06
    return hp(noise(d), 7000) * env(int(d * SR), 0.001, 0.08 if open_ else 0.015) * 0.5


def pluck(n_, d=0.35, kind="square", cut=3500, dec=0.12):
    s = osc(note(n_), d, kind)
    return lp(s, cut) * env(int(d * SR), 0.003, dec, 0, 0.03)


def bass(n_, d):
    s = osc(note(n_), d, "saw") * 0.6 + osc(note(n_ - 12), d, "sine") * 0.6
    return lp(s, 700) * env(int(d * SR), 0.004, 0.25, 0.4, 0.03)


def pad(notes, d, cut=1800):
    s = sum(osc(note(n_) * (1 + dt), d, "saw") for n_ in notes for dt in (-0.004, 0.004))
    s = lp(s, cut) / (len(notes) * 2)
    return s * env(int(d * SR), 0.25, 3.0, 0.7, 0.4)


def addp(*sigs):
    n = max(len(x) for x in sigs)
    out = np.zeros(n)
    for x in sigs:
        out[: len(x)] += x
    return out


def bell(f, d=1.2, g=1.0):
    s = sum(osc(f * m, d) * a * env(int(d * SR), 0.001, d * 0.4 / m ** 0.5) for m, a in ((1, 1), (2.76, 0.4), (5.4, 0.2), (8.9, 0.1)))
    return s * g


# ------------------------------------------------------------------ sound effects
def sfx(kind):
    if kind == "hit":
        d = 0.3
        thump = osc(lambda tt: 70 + 120 * np.exp(-tt * 40), d) * env(int(d * SR), 0.001, 0.07)
        crack = lp(noise(d), 4000) * env(int(d * SR), 0.0005, 0.035)
        ping = osc(1650, d) * env(int(d * SR), 0.001, 0.05) * 0.35
        return thump * 0.9 + crack * 0.8 + ping
    if kind == "gem":
        d = 0.25
        return osc(lambda tt: 1500 + 1400 * np.minimum(tt * 12, 1), d, "tri") * env(int(d * SR), 0.002, 0.06) * 0.6
    if kind == "coin":
        d = 0.45
        a = osc(note(88), d, "square") * env(int(d * SR), 0.001, 0.05)
        b = np.concatenate([np.zeros(int(0.07 * SR)), osc(note(93), d - 0.07, "square") * env(int((d - 0.07) * SR), 0.001, 0.14)])
        return lp(a * 0.5 + b * 0.6, 7000) * 0.6
    if kind == "pop":
        d = 0.15
        return osc(lambda tt: 300 + 900 * np.minimum(tt * 14, 1), d) * env(int(d * SR), 0.001, 0.05)
    if kind == "click":
        d = 0.08
        return hp(noise(d), 2000) * env(int(d * SR), 0.0005, 0.006) * 0.9 + osc(2400, d) * env(int(d * SR), 0.0005, 0.01) * 0.5
    if kind == "levelup":
        out = np.zeros(int(1.2 * SR))
        for i, n_ in enumerate((72, 76, 79, 84, 88)):
            s = pluck(n_, 0.6, "square", 6000, 0.18)
            j = int(i * 0.07 * SR)
            out[j:j + len(s)] += s * 0.6
        return out + hp(noise(1.2), 6000) * env(int(1.2 * SR), 0.3, 0.3) * 0.15
    if kind == "burst":
        d = 0.9
        return lp(noise(d), 2500) * env(int(d * SR), 0.002, 0.18) * 0.8 + osc(lambda tt: 40 + 80 * np.exp(-tt * 10), d) * env(int(d * SR), 0.002, 0.25)
    if kind == "whoosh":
        d = 0.55
        tt = t_(d)
        n = noise(d)
        out = np.zeros_like(n)
        # sweep a band through the noise in chunks
        ch = 512
        for i in range(0, len(n), ch):
            u = i / len(n)
            fc = 400 + 3500 * math.sin(u * math.pi)
            seg = bp(n[max(0, i - 2048):i + ch], fc * 0.6, fc * 1.4)[-min(ch, len(n) - i):]
            out[i:i + len(seg)] = seg
        return out * np.sin(np.pi * tt / d) ** 2 * 1.2
    if kind == "ding":
        return addp(bell(note(84), 1.0, 0.55), bell(note(91), 0.8, 0.25))
    if kind == "motor":
        d = 1.1
        tt = t_(d)
        s = lp(osc(lambda x: 55 + 25 * np.minimum(x * 3, 1), d, "saw"), 400) * (0.7 + 0.3 * np.sin(tt * 2 * np.pi * 9))
        return s * np.sin(np.pi * tt / d) * 0.8
    if kind == "rattle":
        out = np.zeros(int(0.8 * SR))
        for k in range(14):
            g = sfx("gem") if k % 2 else sfx("click")
            j = int((k * 0.045 + RNG.uniform(0, 0.02)) * SR)
            out[j:j + len(g)] += g[: len(out) - j] * 0.5
        return out
    if kind == "horn":
        d = 0.95
        tt = t_(d)
        vib = lambda f: (lambda x: f * (1 + 0.006 * np.sin(x * 2 * np.pi * 5)))
        s = osc(vib(note(45)), d, "saw") + osc(vib(note(52)), d, "saw") * 0.7
        return lp(s, 900) * env(int(d * SR), 0.06, 2.0, 0.8, 0.2) * 0.55
    if kind == "splash":
        d = 0.7
        return lp(noise(d), 1800) * env(int(d * SR), 0.01, 0.18) * 0.7
    if kind == "stamp":
        d = 0.4
        return osc(lambda tt: 40 + 70 * np.exp(-tt * 30), d) * env(int(d * SR), 0.001, 0.12) + lp(noise(d), 2500) * env(int(d * SR), 0.001, 0.04) * 0.6 + osc(900, d) * env(int(d * SR), 0.001, 0.08) * 0.15
    if kind == "cash":
        d = 0.8
        n = hp(noise(0.12), 3000) * env(int(0.12 * SR), 0.001, 0.03) * 0.6
        b = addp(bell(note(88), d, 0.4), bell(note(93), d, 0.3))
        out = np.zeros(int((d + 0.1) * SR))
        out[: len(n)] += n
        j = int(0.08 * SR)
        out[j:j + len(b)] += b
        return out
    if kind == "sizzle":
        d = 0.9
        return hp(noise(d), 5000) * env(int(d * SR), 0.05, 0.35) * 0.4
    if kind == "riser":
        d = 1.3
        tt = t_(d)
        return (bp(noise(d), 800, 6000) * 0.3 + osc(lambda x: 200 + 1200 * (x / d) ** 2, d, "saw") * 0.15) * (tt / d) ** 2
    if kind == "unlock":
        d = 0.9
        clank = (osc(620, d) + osc(1530, d) * 0.6 + osc(2400, d) * 0.3) * env(int(d * SR), 0.001, 0.12) * 0.5
        out = np.zeros(int(d * SR))
        out += clank
        for i, n_ in enumerate((84, 88, 91, 96)):
            s = pluck(n_, 0.4, "tri", 9000, 0.12)
            j = int((0.12 + i * 0.05) * SR)
            out[j:j + len(s)] += s[: len(out) - j] * 0.4
        return out
    if kind == "jackpot":
        out = np.zeros(int(2.2 * SR))
        for i, n_ in enumerate((72, 76, 79, 84, 88, 91, 96, 100)):
            s = pluck(n_, 0.5, "square", 7000, 0.15)
            j = int(i * 0.06 * SR)
            out[j:j + len(s)] += s * 0.45
        for i in range(10):
            b = bell(note(96 + (i % 3) * 4), 0.6, 0.18)
            j = int((0.5 + i * 0.12) * SR)
            out[j:j + len(b)] += b[: len(out) - j]
        return out
    if kind == "boom":
        d = 1.6
        return osc(lambda tt: 38 + 60 * np.exp(-tt * 6), d) * env(int(d * SR), 0.002, 0.5) * 1.1 + lp(noise(d), 1200) * env(int(d * SR), 0.002, 0.2) * 0.5 + hp(noise(d), 6000) * env(int(d * SR), 0.3, 0.4) * 0.12
    if kind == "fanfare":
        out = np.zeros(int(2.0 * SR))
        seq = [(0.0, (67,), 0.12), (0.13, (67,), 0.12), (0.26, (67,), 0.12), (0.4, (72, 76, 79, 84), 1.5)]
        for at, ns, d in seq:
            s = sum(osc(note(n_), d, "saw") for n_ in ns) / len(ns)
            s = lp(s, 2600) * env(int(d * SR), 0.01, 0.6 if d > 1 else 0.1, 0.5 if d > 1 else 0, 0.3 if d > 1 else 0.02)
            j = int(at * SR)
            out[j:j + len(s)] += s * 0.9
        return out
    if kind == "tapestop":
        d = 0.6
        tt = t_(d)
        drop = lambda f: (lambda x: f * np.maximum(0.05, 1 - x / d) ** 1.6)
        sig = sum(osc(drop(note(n_)), d, "saw") for n_ in (48, 60, 64, 67)) / 4
        return lp(sig, 2500) * (1 - tt / d) * 0.9
    if kind == "rewind":
        d = 0.75
        tt = t_(d)
        chirp = osc(lambda x: 900 + 700 * np.sin(x * 2 * np.pi * 11), d, "saw") * 0.25
        return (bp(noise(d), 1500, 6000) * 0.5 + chirp) * np.sin(np.pi * tt / d) * 0.7
    if kind == "sadfast":
        out = np.zeros(int(1.8 * SR))
        for i, (n_, d) in enumerate(((55, 0.24), (54, 0.24), (53, 0.24), (52, 0.9))):
            vib = (lambda f, dd: (lambda x: f * (1 + (0.02 if dd > 0.5 else 0.004) * np.sin(x * 2 * np.pi * 6))))(note(n_), d)
            sgl = lp(osc(vib, d, "saw"), 1400) * env(int(d * SR), 0.02, 3.0, 0.8, 0.1)
            j = int(i * 0.26 * SR)
            out[j:j + len(sgl)] += sgl * 0.55
        return out
    if kind == "sad":
        # the classic descending 'wah wah wah waaah'
        out = np.zeros(int(3.0 * SR))
        for i, (n_, d) in enumerate(((55, 0.45), (54, 0.45), (53, 0.45), (52, 1.3))):
            vib = (lambda f, dd: (lambda x: f * (1 + (0.02 if dd > 1 else 0.004) * np.sin(x * 2 * np.pi * 6))))(note(n_), d)
            s = osc(vib, d, "saw")
            tt = t_(d)
            cut = 500 + 1500 * np.sin(np.pi * np.minimum(tt / 0.35, 1)) ** 2
            s = lp(s, 1400) * (0.5 + 0.5 * cut / 2000)
            s *= env(len(s), 0.03, 3.0, 0.8, 0.12)
            j = int(i * 0.5 * SR)
            out[j:j + len(s)] += s * 0.55
        return out
    raise ValueError(kind)


# ------------------------------------------------------------------ music
BPM = 124
BEAT = 60 / BPM
PROG = [(48, (60, 64, 67)), (43, (59, 62, 67)), (45, (60, 64, 69)), (41, (60, 65, 69))]  # C G Am F
LEAD = [79, 76, 72, 76, 79, 81, 79, 76, 74, 71, 67, 71, 74, 76, 74, 71, 76, 72, 69, 72, 76, 77, 76, 72, 77, 72, 69, 72, 77, 79, 77, 72]


def groove(mix, start, stop, big_from, rich_from):
    t = start
    bar = 0
    beat = BEAT
    while t < stop - 0.01:
        root, chord = PROG[bar % 4]
        big = t >= big_from
        rich = t >= rich_from
        for b in range(4):
            tb = t + b * beat
            if tb >= stop:
                break
            mix.add(tb, kick(), 0.85)
            if b % 2 == 1:
                mix.add(tb, snare(), 0.45)
            for h in range(2):
                mix.add(tb + h * beat / 2, hat(open_=(h == 1 and b == 3)), 0.25 if h else 0.18, pan=0.3)
            for h in range(2):
                if tb + h * beat / 2 < stop:
                    mix.add(tb + h * beat / 2, bass(root + (12 if h else 0), beat / 2 * 0.95), 0.42)
            mix.add(tb + beat / 2, sum(pluck(n_, beat * 0.45, "saw", 2600, 0.08) for n_ in chord) / 3, 0.22, pan=-0.25)
            for h in range(2):
                n_ = LEAD[((bar % 4) * 8 + b * 2 + h) % len(LEAD)]
                g = 0.13 if not big else 0.17
                mix.add(tb + h * beat / 2, pluck(n_, beat * 0.5, "square", 4200, 0.1), g, pan=0.25)
                if big:
                    mix.add(tb + h * beat / 2, pluck(n_ + 12, beat * 0.4, "tri", 8000, 0.07), 0.07, pan=-0.35)
            if rich:
                for h in range(4):
                    mix.add(tb + h * beat / 4, pluck(chord[h % 3] + 24, beat * 0.25, "tri", 9000, 0.04), 0.06, pan=(h % 2) * 0.8 - 0.4)
        mix.add(t, pad(chord, min(4 * beat, stop - t + 0.3), 1500), 0.08)
        t += 4 * beat
        bar += 1


def music(mix, tl):
    up, end, fin = tl["up"], tl["end"], tl["fin"]
    hook, rew = tl.get("hook", 0.0), tl.get("rew", 0.0)
    # hook: the full 'rich' groove straight away, cut by a tape stop
    if rew > 0:
        groove(mix, 0.0, rew, 0.0, 0.0)
    # broke part: soft minor pad + music-box notes
    mix.add(hook + 0.05, pad((57, 60, 64), up - hook, 1200), 0.3)
    for i, n_ in enumerate((76, 72, 69, 71, 72, 69, 67, 64)):
        at = hook + 0.1 + i * 0.3
        if at < up - 0.3:
            mix.add(at, pluck(n_, 0.5, "tri", 5000, 0.2), 0.22, pan=-0.3 + 0.1 * (i % 3))
    for k in range(4):
        mix.add(up - 0.48 + k * 0.12, snare(), 0.18 + k * 0.06)
    groove(mix, up, end, tl["worlds"], tl["rich"])
    beat = BEAT
    # end card: big chord, then a warm held pad
    mix.add(end, kick(), 1.0)
    mix.add(end, sum(pluck(n_, 1.6, "saw", 3000, 0.5) for n_ in (48, 60, 64, 67, 72)) / 4, 0.5)
    mix.add(end + 0.05, pad((60, 64, 67, 71, 74), fin - end, 2200), 0.2)
    mix.add(end, bass(36, fin - end), 0.35)
    for k in range(int((fin - end) / beat)):
        tb = end + k * beat
        if k % 2 == 0 and tb < fin - 0.6:
            mix.add(tb, kick(), 0.4)
        mix.add(tb + beat / 2, hat(), 0.12, pan=0.3)


def write_track(path, events, t0, dur, tl, with_music=True):
    full = tl["fin"] + 1
    mix = Mix(full)
    if with_music:
        music(mix, tl)
    cache = {}
    for at, kind, gain in events:
        if kind not in cache:
            cache[kind] = sfx(kind)
        pan = (hash((round(at, 2), kind)) % 100) / 100 * 0.6 - 0.3
        mix.add(at, cache[kind], gain * 0.6, pan=pan)
    a, b = int(t0 * SR), int((t0 + dur) * SR)
    L, R = mix.L[a:b], mix.R[a:b]
    # gentle bus compression (soft clip) and fades
    st = np.stack([L, R], 1)
    peak = np.max(np.abs(st)) + 1e-9
    st = st / peak * 1.6
    st = np.tanh(st) / np.tanh(1.6) * 0.89
    fi, fo = int(0.05 * SR), int(0.6 * SR)
    st[:fi] *= np.linspace(0, 1, fi)[:, None]
    st[-fo:] *= np.linspace(1, 0, fo)[:, None]
    pcm = (st * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
