#!/usr/bin/env python3
"""Synthesises Vesper's movement and sword sounds into assets/sfx (re-running
overwrites them; deterministic, no dependencies):
  jump.wav             a paper flick: a short bright puff of paper air
  dash.wav             a pen stroke: a nib dragged fast across paper, rising then easing off
  sword_swing_1..4     a miss: a thin nib swish through the air (four takes)
  sword_hit_1..4       a hit: a crisp nib click, a dull ink thwack and a short wet splat
Everything is kept short and dry so it sits under the music and repeats
without tiring. Played by the Sfx autoload (scripts/audio/sfx.gd) by name;
a play picks one of the numbered takes at random.
Run from anywhere: python3 tools/sfx/build_sfx.py
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sfx")
RATE = 44100


# ------------------------------------------------------------------ building blocks

def env(t, attack, decay):
    """Fast linear attack, exponential decay (seconds)."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


class BandPass:
    """RBJ biquad band-pass (constant 0 dB peak); the centre can move per sample."""

    def __init__(self, q):
        self.q = q
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x, freq):
        w = 2.0 * math.pi * min(freq, RATE * 0.45) / RATE
        alpha = math.sin(w) / (2.0 * self.q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1.0 + alpha, -2.0 * math.cos(w), 1.0 - alpha
        y = (b0 * x + b2 * self.x2 - a1 * self.y1 - a2 * self.y2) / a0
        self.x2, self.x1 = self.x1, x
        self.y2, self.y1 = self.y1, y
        return y


class OnePole:
    """One-pole low-pass; `hp=True` gives the matching high-pass."""

    def __init__(self, freq, hp=False):
        self.a = math.exp(-2.0 * math.pi * freq / RATE)
        self.hp = hp
        self.y = 0.0

    def __call__(self, x):
        self.y = (1.0 - self.a) * x + self.a * self.y
        return x - self.y if self.hp else self.y


def paper_grain(rng, density):
    """Paper tooth: mostly 1, with sparse little dips and bumps as the nib catches."""
    return 1.0 + (rng.uniform(-0.6, 0.6) if rng.random() < density else 0.0)


def finish(samples, peak_db):
    """Short fades at both ends, then normalise to `peak_db` dBFS."""
    n = len(samples)
    fade = int(0.004 * RATE)
    for i in range(min(fade, n)):
        samples[i] *= i / fade
        samples[n - 1 - i] *= i / fade
    peak = max(abs(s) for s in samples) or 1.0
    g = 10 ** (peak_db / 20.0) / peak
    return [s * g for s in samples]


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print(f"{name}.wav  {len(samples) / RATE:.2f} s")


# ------------------------------------------------------------------ the sounds

def jump(seed=1):
    """A paper flick: a bright puff of air (band-passed noise rising 900 -> 2600 Hz)
    over a soft low push, gone in a tenth of a second."""
    rng = random.Random(seed)
    n = int(0.13 * RATE)
    bp = BandPass(1.4)
    out = []
    for i in range(n):
        t = i / RATE
        k = t / 0.13
        air = bp(rng.uniform(-1, 1), 900.0 + 1700.0 * math.sqrt(k)) * env(t, 0.004, 0.035) * 2.2
        push = math.sin(2 * math.pi * (140.0 * t + 300.0 * t * t)) * env(t, 0.003, 0.025) * 0.35
        out.append(air + push)
    return finish(out, -4.0)


def dash(seed=2):
    """A pen stroke: noise through a moving band (700 -> 3400 -> 2300 Hz) with paper
    grain, so it reads as a nib dragged fast across the page."""
    rng = random.Random(seed)
    dur = 0.24
    n = int(dur * RATE)
    bp = BandPass(1.1)
    bp2 = BandPass(3.0)
    hp = OnePole(300.0, hp=True)
    out = []
    for i in range(n):
        t = i / RATE
        k = t / dur
        f = 700.0 + 2700.0 * math.sin(math.pi * k * 0.8)  # up to 3400 Hz at 60%, easing back
        a = min(t / 0.03, 1.0) * (1.0 - k) ** 1.6
        x = rng.uniform(-1, 1) * paper_grain(rng, 0.08)
        body = bp(x, f) * 1.6 + bp2(x, f * 1.9) * 0.5
        out.append(hp(body) * a)
    return finish(out, -2.5)


def swing(seed, dur, f0, f1, q):
    """A miss: a thin, fast nib swish (a narrow band sweeping f0 -> f1), loudest
    just past the middle, like a blade cutting air."""
    rng = random.Random(seed)
    n = int(dur * RATE)
    bp = BandPass(q)
    hp = OnePole(500.0, hp=True)
    out = []
    for i in range(n):
        t = i / RATE
        k = t / dur
        f = f0 + (f1 - f0) * (k ** 0.7)
        a = math.sin(math.pi * min(k / 0.6, 1.0) * 0.5) ** 2 if k < 0.6 else ((1.0 - k) / 0.4) ** 2
        out.append(hp(bp(rng.uniform(-1, 1), f)) * a)
    return finish(out, -3.0)


def hit(seed, body_hz, splat_hz):
    """A hit: a crisp click (the nib striking), a dull thwack (a sine dropping an
    octave in 60 ms) and a short wet splat of ink (low-passed noise, bubbling)."""
    rng = random.Random(seed)
    dur = 0.22
    n = int(dur * RATE)
    click_hp = OnePole(2500.0, hp=True)
    splat_lp = OnePole(splat_hz)
    splat_lp2 = OnePole(splat_hz * 1.3)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        click = click_hp(rng.uniform(-1, 1)) * env(t, 0.0005, 0.004) * 1.4
        freq = body_hz * (0.5 + 0.5 * math.exp(-t / 0.03))
        phase += 2 * math.pi * freq / RATE
        thwack = math.sin(phase) * env(t, 0.001, 0.05) * 0.9
        bubble = 1.0 + 0.45 * math.sin(2 * math.pi * 34.0 * t + seed)
        splat = splat_lp2(splat_lp(rng.uniform(-1, 1))) * env(max(t - 0.01, 0.0), 0.012, 0.06) * bubble * 3.2
        out.append(click + thwack + (splat if t > 0.01 else 0.0))
    return finish(out, -1.5)


def main():
    write("jump", jump())
    write("dash", dash())
    takes = [(11, 0.17, 1300, 4800, 2.4), (12, 0.15, 1500, 5400, 2.8), (13, 0.19, 1100, 4200, 2.2), (14, 0.16, 1400, 5000, 2.6)]
    for k, (seed, dur, f0, f1, q) in enumerate(takes, 1):
        write(f"sword_swing_{k}", swing(seed, dur, f0, f1, q))
    for k, (seed, body, splat) in enumerate([(21, 190, 1100), (22, 170, 1000), (23, 210, 1250), (24, 180, 900)], 1):
        write(f"sword_hit_{k}", hit(seed, body, splat))


if __name__ == "__main__":
    main()
