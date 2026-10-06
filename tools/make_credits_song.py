"""The credits' song, "Last Page Stomp": about 23 s of our own loud, stomping
hard rock (played once, by the "credits" track: scripts/audio/music.gd, at
the end of scripts/cutscenes/cs_last_page.gd).

An original tune written here in code, in the style of stadium hard rock:
two crunchy rhythm guitars left and right on a power-chord riff in A, a bass
under them, a four-on-the-floor kit, and a lead guitar that takes a tune of
its own over the second half. Everything is synthesised (sawtooth strings
through a soft-clipping "amp" and a low-pass "cabinet"; drums from sine
sweeps and filtered noise). Needs numpy, scipy and ffmpeg.

    python3 tools/make_credits_song.py        # writes audio/music/credits.ogg

To change it: BPM; RIFF (two bars of chords); LEAD (four bars of tune); the
`arrange()` function says which bars have what.
"""
import os, subprocess, tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
BPM = 138.0
EIGHTH = 60.0 / BPM / 2.0
BAR = EIGHTH * 8.0
rng = np.random.default_rng(7)

# notes
A1, E2, G2, A2, C3, D3 = 55.0, 82.41, 98.0, 110.0, 130.81, 146.83
A4, C5, D5, E5, G5, A5 = 440.0, 523.25, 587.33, 659.26, 783.99, 880.0

## The riff: two bars of [eighth it starts on, eighths long, chord root, palm-muted?].
RIFF = [
    [(0, 1, A2, True), (1, 1, A2, True), (2, 2, A2, False), (4, 1, A2, True), (5, 1, C3, False), (6, 2, D3, False)],
    [(0, 1, A2, True), (1, 1, A2, True), (2, 2, A2, False), (4, 1, A2, True), (5, 1, G2, False), (6, 2, E2, False)],
]
## The lead's tune: four bars of [eighth, eighths long, note].
LEAD = [
    [(0, 2, E5), (2, 1, G5), (3, 1, E5), (4, 2, D5), (6, 1, C5), (7, 1, A4)],
    [(0, 1, C5), (1, 1, D5), (2, 4, E5), (6, 2, G5)],
    [(0, 2, A5), (2, 1, G5), (3, 1, E5), (4, 2, G5), (6, 1, E5), (7, 1, D5)],
    [(0, 2, C5), (2, 2, D5), (4, 4, A4)],
]


def lp(x, fc, order=4):
    return sosfilt(butter(order, fc, "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, "high", fs=SR, output="sos"), x)


def saw(f, n, phase=0.0):
    return 2.0 * ((f * np.arange(n) / SR + phase) % 1.0) - 1.0


def fade(x, a=0.004, r=0.02):
    na, nr = int(a * SR), int(r * SR)
    x = x.copy()
    x[:na] *= np.linspace(0, 1, na)
    x[-nr:] *= np.linspace(1, 0, nr)
    return x


def chord(root, dur, muted, take):
    """A power chord (root, fifth, octave) through the amp. `take` 0 / 1: the
    two guitars are never quite the same."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in (root, root * 1.5, root * 2.0):
        x += saw(f * (1.0 + 0.004 * take), n, rng.random()) + saw(f * (0.997 + 0.003 * take), n, rng.random())
    x = hp(x / 6.0 * np.exp(-t * (16.0 if muted else 1.3)), 80.0)
    x = np.tanh(x * 6.5)                   # the amp, turned up
    x = lp(hp(x, 110.0), 4200.0)           # the cabinet
    if muted:
        x *= np.exp(-t * 7.0)
    return fade(x)


def lead_note(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    wob = 1.0 + 0.007 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.16) / 0.2, 0, 1)   # vibrato comes in on a held note
    ph = np.cumsum(f * wob) / SR
    x = (2.0 * (ph % 1.0) - 1.0) * 0.7 + np.sign(np.sin(2 * np.pi * ph)) * 0.3
    x = np.tanh(x * np.exp(-t * 0.9) * 4.5)
    return fade(lp(hp(x, 250.0), 5200.0), 0.006, 0.03)


def bass_note(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = lp(saw(f, n), 420.0) * 0.8 + np.sin(2 * np.pi * f * t) * 0.6
    return fade(x * np.exp(-t * 3.0), 0.004, 0.03)


def kick():
    t = np.arange(int(0.32 * SR)) / SR
    f = 46.0 + 120.0 * np.exp(-t * 34.0)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9.0)
    return x + hp(rng.standard_normal(t.size), 2500.0) * np.exp(-t * 180.0) * 0.25


def snare():
    t = np.arange(int(0.28 * SR)) / SR
    crack = lp(hp(rng.standard_normal(t.size), 900.0), 7500.0) * np.exp(-t * 17.0)
    return crack * 0.8 + np.sin(2 * np.pi * 196.0 * t) * np.exp(-t * 24.0) * 0.6


def hat():
    t = np.arange(int(0.08 * SR)) / SR
    return hp(rng.standard_normal(t.size), 7500.0, 4) * np.exp(-t * 60.0)


def crash():
    t = np.arange(int(2.4 * SR)) / SR
    return hp(rng.standard_normal(t.size), 4200.0, 4) * np.exp(-t * 2.0)


def arrange():
    total = int((BAR * 12 + 3.2) * SR)
    mix = np.zeros((total, 2))

    def put(x, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        x = x[: max(total - i, 0)]
        mix[i : i + x.size, 0] += x * gain * (1.0 - max(pan, 0.0))
        mix[i : i + x.size, 1] += x * gain * (1.0 + min(pan, 0.0))

    k, sn, h, cr = kick(), snare(), hat(), crash()
    for bar in range(11):
        at = bar * BAR
        # two guitars on the riff, left and right (one alone for the first two bars)
        for start, length, root, muted in RIFF[bar % 2]:
            for take, pan in ((0, -0.75), (1, 0.75)):
                if bar >= 2 or take == 0:
                    put(chord(root, length * EIGHTH * 0.97, muted, take), at + start * EIGHTH, 0.5, pan if bar >= 2 else -0.2)
            if bar >= 2:
                put(bass_note(root / 2.0, length * EIGHTH * 0.95), at + start * EIGHTH, 0.5)
        # the kit: hats count the first two bars in, then kick on 1 and 3 (and a push), snare on 2 and 4
        for e in range(8):
            put(h, at + e * EIGHTH, 0.16 if bar >= 2 else 0.24, 0.3)
        if bar >= 2:
            for e in (0, 3, 4):
                put(k, at + e * EIGHTH, 0.95)
            for e in (2, 6):
                put(sn, at + e * EIGHTH, 0.8)
            if bar in (2, 6):
                put(cr, at, 0.3, -0.2)
        # the lead takes its tune over bars 7-10
        if 6 <= bar < 10:
            for start, length, note in LEAD[bar - 6]:
                x = lead_note(note, length * EIGHTH * 0.96)
                put(x, at + start * EIGHTH, 0.4, 0.1)
                put(x, at + start * EIGHTH + EIGHTH * 1.5, 0.11, -0.4)   # an echo of it
        if bar == 10:  # a roll round the snare into the last chord
            for e in range(8):
                put(sn, at + BAR * 0.5 + e * EIGHTH * 0.5, 0.45 + 0.05 * e)
    # the last chord: everybody lands on A and lets it ring
    end = 11 * BAR
    for take, pan in ((0, -0.75), (1, 0.75)):
        put(chord(A2, 3.0, False, take), end, 0.6, pan)
    put(bass_note(A1, 2.6), end, 0.6)
    put(k, end, 1.0)
    put(sn, end, 0.7)
    put(cr, end, 0.42, 0.2)
    put(lead_note(A5, 2.6), end, 0.3, 0.1)
    # the desk: a little glue, and the ring-out faded
    mix = np.tanh(mix * 1.15)
    tail = int(1.2 * SR)
    mix[-tail:] *= np.linspace(1, 0, tail)[:, None]
    return mix / np.max(np.abs(mix)) * 0.89


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music", "credits.ogg")
    mix = arrange()
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "credits.wav")
        wavfile.write(wav, SR, (mix * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", "loudnorm=I=-15:TP=-1.5:LRA=9",
                        "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    print("wrote", os.path.normpath(out), "%.1f s" % (mix.shape[0] / SR))


if __name__ == "__main__":
    main()
