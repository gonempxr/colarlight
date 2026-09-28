"""Synthesizes every sound in the game: no samples, no third-party audio.

    python3 tools/make_audio.py      # writes game/assets/audio/*.ogg

Needs numpy, scipy and soundfile (pip). Instruments are small physical-ish
models: Karplus-Strong plucks (ukulele), modal marimba/kalimba/bells, soft
pads, a round bass and light percussion, all through a shared reverb.
Character voices ("oh!", "yay!", "woo-hoo!") are additive formant
synthesis at a cartoon pitch.
"""
import os

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "audio")
SR = 44100
rng = np.random.default_rng(11)


# --- Basics ------------------------------------------------------------------

def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def adsr(n, a=0.005, d=0.05, s=0.7, r=0.1):
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = max(1, min(ai, n))
    e[:ai] = np.linspace(0, 1, ai)
    if di > 0 and ai + di < n:
        e[ai:ai + di] = np.linspace(1, s, di)
    ri = max(1, min(ri, n))
    e[-ri:] *= np.linspace(1, 0, ri) ** 1.5
    return e


def fade(x, ms=4):
    k = max(1, int(ms / 1000 * SR))
    x = x.copy()
    x[:k] *= np.linspace(0, 1, k)
    x[-k:] *= np.linspace(1, 0, k)
    return x


def place(buf, clip, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(clip))
    buf[i:end] += clip[:end - i]


def lowpass(x, hz, order=2):
    b, a = signal.butter(order, min(hz, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


_ir_cache = {}


def reverb(x, size=1.6, mix=0.25, bright=5000):
    key = (size, bright)
    if key not in _ir_cache:
        t = t_axis(size)
        ir = rng.standard_normal(len(t)) * np.exp(-t * 6.0 / size)
        ir = lowpass(ir, bright)
        ir[: int(0.012 * SR)] = 0
        _ir_cache[key] = ir / np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, _ir_cache[key])[: len(x) + len(_ir_cache[key])]
    out = np.zeros(len(wet))
    out[: len(x)] += x * (1 - mix)
    out += wet * mix * 0.9
    return out


# --- Instruments --------------------------------------------------------------

def modal(freq, sec, ratios, decays, amps, attack=0.002):
    t = t_axis(sec)
    y = np.zeros(len(t))
    for r, d, a in zip(ratios, decays, amps):
        if freq * r < SR * 0.45:
            y += a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * d)
    return y * adsr(len(t), attack, 0, 1, min(0.03, sec / 4))


def marimba(freq, sec=0.9):
    return modal(freq, sec, [1, 3.93, 9.2], [5.5, 18, 40], [1, 0.35, 0.12])


def kalimba(freq, sec=1.2):
    return modal(freq, sec, [1, 5.4, 11.3], [3.2, 16, 30], [1, 0.3, 0.1], 0.001)


def bell(freq, sec=1.6):
    return modal(freq, sec, [1, 2.76, 5.4, 8.9], [2.2, 4, 7, 12], [1, 0.5, 0.25, 0.1])


def coin_ping(freq, sec=0.5):
    return modal(freq, sec, [1, 2.32, 3.87, 5.1], [7, 9, 13, 17], [1, 0.6, 0.4, 0.2], 0.0005)


def pluck(freq, sec=1.4, bright=0.6, damp=0.996):
    """Karplus-Strong string (ukulele-ish)."""
    n = int(sec * SR)
    period = SR / freq
    N = int(period)
    frac = period - N
    burst = rng.uniform(-1, 1, N + 2)
    burst = lowpass(burst, 1500 + bright * 6000, 1)
    x = np.zeros(n)
    x[: len(burst)] = burst
    # y[n] = x[n] + damp*((1-frac)*y[n-N] + frac*y[n-N-1]) averaged for lowpass
    a = np.zeros(N + 3)
    a[0] = 1.0
    a[N] -= damp * 0.5 * (1 - frac)
    a[N + 1] -= damp * 0.5
    a[N + 2] -= damp * 0.5 * frac
    y = signal.lfilter([1.0], a, x)
    y /= max(1e-6, np.max(np.abs(y)))
    return y * adsr(n, 0.001, 0, 1, 0.08)


def pad(freqs, sec, bright=1800):
    t = t_axis(sec)
    y = np.zeros(len(t))
    for f in freqs:
        for det in (-0.004, 0.0, 0.004):
            ph = rng.uniform(0, 2 * np.pi)
            saw = 2 * ((t * f * (1 + det) + ph / (2 * np.pi)) % 1) - 1
            y += saw
    y = lowpass(y, bright, 2) / (len(freqs) * 3)
    return y * adsr(len(t), min(0.8, sec / 3), 0, 1, min(1.0, sec / 3))


def bass(freq, sec):
    t = t_axis(sec)
    y = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t) + 0.08 * (2 * ((t * freq) % 1) - 1)
    return lowpass(y, 900) * adsr(len(t), 0.01, 0.2, 0.75, 0.08)


def flute(freq, sec):
    t = t_axis(sec)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 3, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    breath = bandpass(rng.standard_normal(len(t)), freq * 0.9, freq * 3.5) * 0.05
    return (y + breath) * adsr(len(t), 0.06, 0.1, 0.8, 0.12)


def kick(sec=0.35):
    t = t_axis(sec)
    f = 45 + 80 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def shaker(sec=0.06):
    t = t_axis(sec)
    return highpass(rng.standard_normal(len(t)), 6000) * np.exp(-t * 60)


def rim(sec=0.08):
    t = t_axis(sec)
    return bandpass(rng.standard_normal(len(t)), 1500, 4000) * np.exp(-t * 70) + np.sin(2 * np.pi * 820 * t) * np.exp(-t * 60) * 0.5


# --- Voices -------------------------------------------------------------------

VOWELS = {
    "a": [(1000, 90, 1.0), (1500, 110, 0.55), (3000, 200, 0.2)],
    "o": [(600, 80, 1.0), (1000, 100, 0.5), (2800, 200, 0.12)],
    "u": [(420, 70, 1.0), (900, 100, 0.35), (2600, 200, 0.08)],
    "e": [(620, 80, 1.0), (2300, 120, 0.5), (3200, 200, 0.2)],
    "i": [(360, 70, 1.0), (2800, 130, 0.5), (3700, 200, 0.2)],
    "m": [(280, 60, 1.0), (1900, 200, 0.05), (2800, 250, 0.03)],
}


def voice(segments, pitch=1.0):
    """segments: list of (seconds, vowel_from, vowel_to, f0_from, f0_to, gain)."""
    out = []
    for sec, v0, v1, p0, p1, g in segments:
        t = t_axis(sec)
        n = len(t)
        k = np.linspace(0, 1, n)
        f0 = (p0 + (p1 - p0) * (k ** 0.8)) * pitch
        f0 = f0 * (1 + 0.012 * np.sin(2 * np.pi * 6.0 * t))
        phase = 2 * np.pi * np.cumsum(f0) / SR
        y = np.zeros(n)
        F0 = np.array(VOWELS[v0])
        F1 = np.array(VOWELS[v1])
        for h in range(1, 40):
            fh = f0 * h
            if np.min(fh) > 5000:
                break
            amp = np.zeros(n)
            for j in range(3):
                fc = F0[j, 0] + (F1[j, 0] - F0[j, 0]) * k
                bw = F0[j, 1] + (F1[j, 1] - F0[j, 1]) * k
                ga = F0[j, 2] + (F1[j, 2] - F0[j, 2]) * k
                amp += ga / (1 + ((fh - fc) / bw) ** 2)
            y += amp * np.sin(h * phase) / (h ** 0.3)
        y *= adsr(n, 0.02, 0.05, 0.9, min(0.08, sec / 2)) * g
        out.append(y)
    y = np.concatenate(out)
    return y / max(1e-6, np.max(np.abs(y)))


def breath(sec):
    t = t_axis(sec)
    return bandpass(rng.standard_normal(len(t)), 1200, 5000) * adsr(len(t), 0.01, 0.02, 0.6, 0.03) * 0.25


# --- Sound effects --------------------------------------------------------------

def sweep(f0, f1, sec, curve=1.0):
    t = t_axis(sec)
    k = np.linspace(0, 1, len(t)) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def make_sfx():
    s = {}
    buf = np.zeros(int(0.15 * SR))
    place(buf, marimba(midi(84), 0.15) * 0.8, 0)
    place(buf, marimba(midi(96), 0.08) * 0.2, 0)
    s["click"] = fade(buf)
    t = t_axis(0.07)
    s["pop"] = fade(sweep(380, 1250, 0.07, 0.6) * np.exp(-t * 35))
    t = t_axis(0.09)
    s["tap"] = fade(sweep(1500, 700, 0.09, 0.5) * np.exp(-t * 40) * 0.8 + bandpass(rng.standard_normal(len(t)), 2000, 6000) * np.exp(-t * 90) * 0.15)
    buf = np.zeros(int(0.4 * SR))
    place(buf, marimba(midi(64), 0.3) * 0.8, 0)
    place(buf, marimba(midi(60), 0.3) * 0.8, 0.11)
    s["deny"] = lowpass(buf, 2500)
    buf = np.zeros(int(0.7 * SR))
    for i, m in enumerate([72, 76, 79, 84]):
        place(buf, marimba(midi(m), 0.5) * (0.7 + i * 0.1), i * 0.045)
    place(buf, bell(midi(96), 0.5) * 0.25, 0.2)
    s["upgrade"] = reverb(buf, 0.8, 0.18)
    buf = np.zeros(int(1.2 * SR))
    for m in (72, 76, 79):
        place(buf, kalimba(midi(m), 1.0) * 0.5, 0)
    for i, m in enumerate([84, 88, 91]):
        place(buf, bell(midi(m), 0.8) * 0.35, 0.12 + i * 0.07)
    s["hire"] = reverb(buf, 1.0, 0.22)
    buf = np.zeros(int(2.0 * SR))
    for i, m in enumerate([60, 64, 67, 72]):
        place(buf, pluck(midi(m), 1.2) * 0.45, i * 0.03)
    for i, m in enumerate([72, 76, 79, 84, 88]):
        place(buf, bell(midi(m), 1.2) * 0.35, 0.25 + i * 0.08)
    s["unlock"] = reverb(buf, 1.4, 0.25)
    # Splash: noise burst falling in pitch + bubbles.
    t = t_axis(0.6)
    noise = rng.standard_normal(len(t))
    splash = np.zeros(len(t))
    for lo, hi, g in [(300, 1200, 1.0), (1200, 4000, 0.5)]:
        splash += bandpass(noise, lo, hi) * g
    splash *= np.exp(-t * 7) * adsr(len(t), 0.004, 0, 1, 0.1)
    buf = splash
    for i in range(6):
        bt = t_axis(0.05)
        place(buf, sweep(500 + i * 110, 1300 + i * 150, 0.05, 0.5) * np.exp(-bt * 40) * 0.35, 0.12 + i * 0.055)
    s["dive"] = fade(buf)
    # Pick on rock: click + thud + short ping.
    t = t_axis(0.25)
    click = bandpass(rng.standard_normal(len(t)), 1800, 6000) * np.exp(-t * 90)
    thud = np.sin(2 * np.pi * np.cumsum(140 * np.exp(-t * 8) + 60) / SR) * np.exp(-t * 25)
    s["dig"] = fade(click * 0.8 + thud * 0.7 + coin_ping(1900, 0.25) * 0.18)
    # Boat horn: two friendly toots.
    buf = np.zeros(int(0.9 * SR))
    for at, dur in ((0.0, 0.2), (0.28, 0.34)):
        ht = t_axis(dur)
        f = 233 * (1 + 0.01 * np.sin(2 * np.pi * 6 * ht))
        ph = np.cumsum(f) / SR
        tone = (2 * (ph % 1) - 1) + 0.7 * (2 * ((ph * 1.498) % 1) - 1)
        place(buf, lowpass(tone, 1100, 2) * adsr(len(ht), 0.02, 0.02, 0.9, 0.06) * 0.6, at)
    s["horn"] = reverb(buf, 0.8, 0.15)
    # Plant: chug-chug and a ding.
    buf = np.zeros(int(0.8 * SR))
    for at in (0.0, 0.16):
        ct = t_axis(0.12)
        place(buf, lowpass(rng.standard_normal(len(ct)), 900) * np.exp(-ct * 30) * 1.2 + np.sin(2 * np.pi * 90 * ct) * np.exp(-ct * 25), at)
    place(buf, bell(midi(88), 0.5) * 0.3, 0.34)
    s["machine"] = fade(buf)
    buf = np.zeros(int(0.7 * SR))
    for i in range(5):
        place(buf, coin_ping(rng.uniform(1500, 2400), 0.4) * rng.uniform(0.35, 0.6), i * 0.05 + rng.uniform(0, 0.02))
    s["coins"] = reverb(buf, 0.6, 0.15)
    buf = np.zeros(int(1.8 * SR))
    for i, m in enumerate([67, 72, 76, 79, 84]):
        place(buf, pluck(midi(m), 1.0) * 0.5, i * 0.07)
    for i in range(10):
        place(buf, bell(midi(rng.choice([91, 93, 96, 98, 100])), 0.4) * 0.18, 0.4 + i * 0.05)
    s["milestone"] = reverb(buf, 1.2, 0.25)
    t = t_axis(0.8)
    whoosh = bandpass(rng.standard_normal(len(t)), 400, 3000) * np.sin(np.pi * t / 0.8) ** 2
    buf = whoosh * 0.6
    for i, m in enumerate([72, 76, 79, 84, 88, 91]):
        place(buf, marimba(midi(m), 0.4) * 0.4, 0.1 + i * 0.06)
    s["rush"] = reverb(buf, 0.9, 0.2)
    t = t_axis(3.0)
    swell = pad([midi(m) for m in (48, 55, 60, 64, 67)], 3.0, 2500) * np.sin(np.pi * np.clip(t / 3.0, 0, 1)) * 1.4
    buf = swell
    for i, m in enumerate([72, 76, 79, 84, 88, 91, 96]):
        place(buf, bell(midi(m), 1.5) * 0.35, 1.0 + i * 0.1)
    s["prestige"] = reverb(buf, 2.0, 0.35)
    buf = np.zeros(int(0.9 * SR))
    for i in range(9):
        place(buf, bell(midi(84 + (i * 7) % 15), 0.4) * 0.35, i * 0.04)
    s["chest"] = reverb(buf, 0.9, 0.25)
    buf = np.zeros(int(1.6 * SR))
    for i, m in enumerate([60, 64, 67, 72, 76]):
        place(buf, pluck(midi(m), 1.3) * 0.5, i * 0.025)
    place(buf, bell(midi(84), 1.0) * 0.35, 0.2)
    place(buf, bell(midi(91), 1.0) * 0.25, 0.3)
    s["start"] = reverb(buf, 1.2, 0.25)
    # Voices.
    s["voice_wow"] = fade(voice([(0.07, "u", "o", 430, 470, 0.7), (0.3, "o", "o", 500, 380, 1.0)]))
    s["voice_yay"] = fade(voice([(0.08, "i", "e", 380, 430, 0.8), (0.3, "e", "i", 470, 600, 1.0)]))
    wo = voice([(0.18, "u", "u", 420, 460, 1.0)])
    hoo = voice([(0.3, "u", "o", 520, 680, 1.0)])
    buf = np.zeros(len(wo) + len(hoo) + int(0.06 * SR))
    place(buf, wo, 0)
    place(buf, breath(0.05), len(wo) / SR)
    place(buf, hoo, len(wo) / SR + 0.04)
    s["voice_woohoo"] = fade(buf)
    s["voice_hmm"] = fade(voice([(0.4, "m", "m", 330, 380, 1.0)]) * 0.8)
    s["voice_ooh"] = fade(voice([(0.45, "o", "u", 360, 540, 1.0)]))
    s["voice_hup"] = fade(voice([(0.12, "a", "u", 420, 360, 1.0)]))
    for name, data in s.items():
        save(name, data)


# --- Ambience and music -------------------------------------------------------

def make_ambience():
    sec = 12.0
    t = t_axis(sec)
    n = len(t)
    brown = np.cumsum(rng.standard_normal(n))
    brown = highpass(brown, 30)
    bed = lowpass(brown, 380)
    bed = bed / np.max(np.abs(bed)) * 0.5
    swell = 0.7 + 0.3 * np.sin(2 * np.pi * t / sec)
    y = bed * swell
    for _ in range(26):
        at = rng.uniform(0, sec - 0.2)
        bt = t_axis(0.06)
        f0 = rng.uniform(500, 1100)
        place(y, sweep(f0, f0 * 2.2, 0.06, 0.5) * np.exp(-bt * 45) * rng.uniform(0.05, 0.15), at)
    # Wrap the start/end so the loop is seamless.
    k = int(0.5 * SR)
    y[:k] = y[:k] * np.linspace(0, 1, k) + y[-k:] * np.linspace(1, 0, k)
    y = y[: n - k]
    save("ambience", y, peak=0.5)


MELODY_A = [
    [76, None, 79, None, 81, 79, 76, None], [72, None, 76, None, 74, 72, 69, None],
    [69, 72, 77, None, 76, None, 72, None], [74, None, None, 71, 74, None, 79, None],
    [76, None, 79, None, 84, None, 83, 81], [79, None, 76, None, 72, None, 76, None],
    [77, None, 76, 74, 72, None, 69, None], [71, None, 74, None, 67, None, None, None],
]
MELODY_B = [
    [81, None, 79, None, 77, None, 72, None], [83, None, 81, None, 79, None, 74, None],
    [79, None, 76, 79, 83, None, 81, 79], [76, None, None, None, 72, None, 76, None],
    [77, None, 81, None, 86, None, 84, None], [83, None, 79, None, 74, None, 79, None],
    [76, 79, 84, None, 79, None, 76, None], [72, None, None, None, None, None, None, None],
]
CHORDS_A = [[48, 60, 64, 67], [45, 57, 60, 64], [41, 57, 60, 65], [43, 55, 59, 62],
            [48, 60, 64, 67], [45, 57, 60, 64], [38, 57, 60, 65], [43, 55, 59, 62]]
CHORDS_B = [[41, 57, 60, 65], [43, 55, 59, 62], [40, 55, 59, 64], [45, 57, 60, 64],
            [38, 57, 62, 65], [43, 55, 59, 65], [48, 60, 64, 67], [48, 55, 60, 64]]


def make_music():
    bpm = 94
    beat = 60 / bpm
    bar = 4 * beat
    sections = [("A", 0), ("A", 1), ("B", 2), ("A", 3)]
    bars = 8 * len(sections)
    length = bars * bar
    tail = 3.0
    n = int((length + tail) * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    Lw = np.zeros(n)
    Rw = np.zeros(n)

    def put(clip, at, pan=0.0, wet=0.3, gain=1.0):
        l = clip * gain * np.sqrt(0.5 * (1 - pan))
        r = clip * gain * np.sqrt(0.5 * (1 + pan))
        place(L, l * (1 - wet), at)
        place(R, r * (1 - wet), at)
        place(Lw, l * wet, at)
        place(Rw, r * wet, at)

    for si, (name, rep) in enumerate(sections):
        mel = MELODY_A if name == "A" else MELODY_B
        chords = CHORDS_A if name == "A" else CHORDS_B
        for b in range(8):
            t0 = (si * 8 + b) * bar
            ch = chords[b]
            # Pad.
            put(pad([midi(m) for m in ch[1:]], bar + 0.4, 1400), t0, 0.0, 0.5, 0.35)
            # Bass: root on 1, fifth-ish walk on 3.
            put(bass(midi(ch[0] - 12 + 12), beat * 1.6), t0, 0.0, 0.1, 0.55)
            put(bass(midi(ch[0] - 12 + (19 if b % 2 else 12)), beat * 1.2), t0 + 2 * beat, 0.0, 0.1, 0.45)
            # Ukulele strums on the off-beats.
            for k in range(4):
                at = t0 + k * beat + beat / 2
                for j, m in enumerate(ch[1:]):
                    put(pluck(midi(m + 12), 0.7, 0.35, 0.993), at + j * 0.012, -0.35, 0.25, 0.12)
            # Percussion from the second section on.
            if si >= 1:
                for k in range(4):
                    if k in (0, 2):
                        put(kick(), t0 + k * beat, 0.0, 0.05, 0.5)
                    else:
                        put(rim(), t0 + k * beat, 0.2, 0.2, 0.12)
                for k in range(8):
                    put(shaker(), t0 + k * beat / 2, 0.45, 0.1, 0.06 if k % 2 else 0.1)
            # Melody: marimba first, flute over the bridge, both at the end.
            for k, m in enumerate(mel[b]):
                if m is None:
                    continue
                at = t0 + k * beat / 2
                if name == "B":
                    dur = beat / 2
                    for kk in range(k + 1, 8):
                        if mel[b][kk] is not None:
                            break
                        dur += beat / 2
                    put(flute(midi(m), dur * 0.95), at, 0.15, 0.35, 0.22)
                else:
                    put(marimba(midi(m), 0.8), at, 0.15, 0.3, 0.42)
                    if rep >= 1:
                        put(kalimba(midi(m - 12 + (3 if (m % 12) in (4, 9) else 4)), 0.9), at + 0.01, -0.25, 0.35, 0.16)
                    if rep == 3:
                        put(bell(midi(m + 12), 0.8), at, 0.3, 0.5, 0.06)
    # Bubbles sprinkled lightly.
    for _ in range(40):
        at = rng.uniform(0, length)
        bt = t_axis(0.06)
        f0 = rng.uniform(600, 1200)
        put(sweep(f0, f0 * 2, 0.06, 0.5) * np.exp(-bt * 45), at, rng.uniform(-0.8, 0.8), 0.4, 0.035)
    Lw = reverb(Lw, 2.2, 1.0, 4500)[:n]
    Rw = reverb(Rw, 2.3, 1.0, 4500)[:n]
    L += Lw
    R += Rw
    # Wrap the tail into the start so the loop is seamless.
    k = int(length * SR)
    L[: n - k] += L[k:]
    R[: n - k] += R[k:]
    st = np.stack([L[:k], R[:k]], axis=1)
    save("music", st, peak=0.8)


def save(name, data, peak=0.85):
    data = np.asarray(data, dtype=np.float64)
    m = np.max(np.abs(data)) or 1.0
    data = np.tanh(data / m * 1.1) / np.tanh(1.1) * peak
    os.makedirs(OUT, exist_ok=True)
    data = data.astype(np.float32)
    channels = 1 if data.ndim == 1 else data.shape[1]
    # Written in blocks: libsndfile's Vorbis encoder can crash on one huge write.
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, channels, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 16384):
            f.write(data[i:i + 16384])


if __name__ == "__main__":
    for f in os.listdir(OUT) if os.path.isdir(OUT) else []:
        if f.endswith(".wav") or f.endswith(".wav.import"):
            os.remove(os.path.join(OUT, f))
    make_sfx()
    make_ambience()
    make_music()
    total = 0
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".ogg"):
            size = os.path.getsize(os.path.join(OUT, f))
            total += size
            print(f, size // 1024, "KB")
    print("total", total // 1024, "KB")
