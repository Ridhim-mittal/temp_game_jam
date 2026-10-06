"""The 2D story's music: three original loops, written to sit under play.

    cd audio/music && python3 ../../tools/make_music_2d.py [city] [deep] [beast]

  city   THE CITY: a slow, warm groove (F minor, 92 bpm): electric piano on
         lazy syncopated 9th chords, a round bass, brushed drums, a vibraphone
         tune the second time round. Rolled off above ~3 kHz so it never sparkles.
  deep   THE LONG DROP: quiet and far down (E minor, 104 bpm): a kalimba
         arpeggio picking its way through the dark, a cold pad, water dripping
         in the distance; the second half adds a soft pulse and a low marimba.
  beast  THE SCRIBBLED BEAST: a driving fight (E phrygian, 160 bpm): low string
         ostinato, taiko and kit, brass stabs, a horn line; a tense pedal section
         that builds back into the theme. Highs rolled off, so it's heavy, not shrill.

Every loop is seamless (note tails and the reverb wrap round) and is rendered
to the same loudness, quiet; music.gd turns them down further (TRIM).
Shares the synth helpers of make_music.py. Deterministic.
"""
import sys, os, wave, subprocess
import numpy as np
from scipy.signal import butter, sosfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_music import SR, Track, env, kick, hat  # noqa: E402
from make_music import nf as _nf  # noqa: E402

FLATS = {'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#'}


def nf(name):          # "Ab3" -> frequency (flats welcome)
    return _nf(FLATS.get(name[:-1], name[:-1]) + name[-1])

rng = np.random.default_rng(23)


# ------------------------------------------------------------- instruments
def lowpass(y, fc, order=2):
    return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), y)


def highpass(y, fc, order=2):
    return sosfilt(butter(order, fc, 'high', fs=SR, output='sos'), y)


def epiano(f, dur):     # Rhodes-ish: soft tine + a bell partial, slow tremolo
    n = int(SR * (dur + 1.4)); t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t * 1.1)
         + 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 2.6)
         + 0.12 * np.sin(2 * np.pi * f * 7.02 * t) * np.exp(-t * 9))
    y *= 1 + 0.18 * np.sin(2 * np.pi * 4.2 * t)
    rel = np.ones(n); nd = int(dur * SR); rel[nd:] = np.exp(-np.arange(n - nd) / SR * 6)
    return y * rel * env(n, 0.004, 0.05) * 0.4


def round_bass(f, dur):  # upright-ish round bass, a little body
    n = int(SR * (dur + 0.25)); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) + 0.08 * np.sin(6 * np.pi * f * t)
    y = np.tanh(y * 1.4) * np.exp(-t * 1.3)
    rel = np.ones(n); nd = int(dur * SR); rel[nd:] = np.exp(-np.arange(n - nd) / SR * 18)
    return y * rel * env(n, 0.008, 0.05) * 0.7


def vibes(f, dur):      # vibraphone: pure bar tone with a gentle motor vibrato
    n = int(SR * (dur + 2.2)); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 6)
    y *= (1 + 0.25 * np.sin(2 * np.pi * 5.5 * t)) * np.exp(-t * 1.4)
    return y * env(n, 0.003, 0.08) * 0.42


def soft_kick(f=0, dur=0):
    return lowpass(kick(), 900) * 0.8


def brush(f=0, dur=0):  # brushed snare: a soft swish of filtered noise
    n = int(SR * 0.35); t = np.arange(n) / SR
    y = highpass(lowpass(rng.standard_normal(n), 3500), 400) * np.exp(-t * 13)
    return y * env(n, 0.01, 0.05) * 0.5


def rim(f=0, dur=0):    # rim click, dull
    n = int(SR * 0.08); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 820 * t) * np.exp(-t * 70) + 0.3 * rng.standard_normal(n) * np.exp(-t * 120)
    return lowpass(y, 2500) * 0.35


def shaker(f=0, dur=0):
    n = int(SR * 0.07); t = np.arange(n) / SR
    y = highpass(rng.standard_normal(n), 4000) * np.sin(np.pi * t / t[-1]) ** 2
    return y * 0.12


def kalimba(f, dur):    # thumb piano: quick bright attack, a hollow body
    n = int(SR * 2.0); t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t * 2.4)
         + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 18)
         + 0.1 * np.sin(2 * np.pi * f * 3.0 * t) * np.exp(-t * 8))
    return y * env(n, 0.002, 0.05) * 0.5


def marimba(f, dur):    # low wooden bars
    n = int(SR * 1.2); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 14)
    return y * env(n, 0.002, 0.05) * 0.55


def cold_pad(f, dur):   # dark slow pad, filtered saw-ish stack
    n = int(SR * (dur + 2.0)); t = np.arange(n) / SR; y = np.zeros(n)
    for det in (0.996, 1.0, 1.004):
        ph = rng.uniform(0, 6)
        for k in range(1, 6):
            y += np.sin(2 * np.pi * f * det * k * t + ph * k) / k
    y = lowpass(y, 900) * (1 + 0.15 * np.sin(2 * np.pi * 0.17 * t))
    return y * env(n, min(1.5, dur * 0.4), 1.8) * 0.12


def drip(f, dur):       # a water drop far off in the cave: a falling blip
    n = int(SR * 0.6); t = np.arange(n) / SR
    fq = f * (1 + 1.2 * np.exp(-t * 60))
    y = np.sin(2 * np.pi * np.cumsum(fq) / SR) * np.exp(-t * 11)
    return y * env(n, 0.001, 0.05) * 0.3


def drone(f, dur):      # sub drone, just felt
    n = int(SR * (dur + 1.0)); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.003 * t)
    return y * env(n, 1.5, 1.5) * 0.25


def strings(f, dur):    # sustained string section
    n = int(SR * (dur + 0.6)); t = np.arange(n) / SR; y = np.zeros(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    for det in (0.995, 1.0, 1.005):
        ph = rng.uniform(0, 6)
        for k in range(1, 9):
            y += np.sin(2 * np.pi * f * det * k * np.cumsum(vib) / SR + ph * k) / k
    y = lowpass(y, 2400)
    return y * env(n, min(0.12, dur * 0.3), 0.35) * 0.07


def spicc(f, dur):      # short bowed string note for the ostinato
    n = int(SR * 0.28); t = np.arange(n) / SR; y = np.zeros(n)
    for det in (0.996, 1.004):
        for k in range(1, 8):
            y += np.sin(2 * np.pi * f * det * k * t) / k
    y = lowpass(y, 2200) * np.exp(-t * 14)
    return y * env(n, 0.006, 0.04) * 0.22


def brass(f, dur):      # horn section: saw stack with a filter that opens on the attack
    n = int(SR * (dur + 0.3)); t = np.arange(n) / SR; y = np.zeros(n)
    for det in (0.997, 1.003):
        for k in range(1, 12):
            y += np.sin(2 * np.pi * f * det * k * t) / k * np.exp(-t * k * 0.35)
    bright = lowpass(y, 3300); dark = lowpass(y, 700)
    a = np.clip(np.exp(-t * 5), 0, 1)
    y = dark + (bright - dark) * (0.35 + 0.65 * a)
    return y * env(n, 0.03, 0.2) * 0.1


def taiko(f=0, dur=0):  # big low drum
    n = int(SR * 0.9); t = np.arange(n) / SR
    ph = 2 * np.pi * (58 * t + 50 / 18 * (1 - np.exp(-18 * t)))
    y = np.sin(ph) * np.exp(-t * 5) + 0.25 * lowpass(rng.standard_normal(n), 700) * np.exp(-t * 20)
    return y * env(n, 0.002, 0.08) * 0.9


def tom(f=0, dur=0):
    n = int(SR * 0.4); t = np.arange(n) / SR
    fq = (f or 110) * (1 + 0.5 * np.exp(-t * 25))
    y = np.sin(2 * np.pi * np.cumsum(fq) / SR) * np.exp(-t * 9)
    return y * env(n, 0.002, 0.05) * 0.6


def snare_hit(f=0, dur=0):
    n = int(SR * 0.25); t = np.arange(n) / SR
    y = lowpass(rng.standard_normal(n), 5000) * np.exp(-t * 20) * 0.55 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 28) * 0.6
    return y * env(n, 0.001, 0.05)


def crash(f=0, dur=0):  # soft cymbal swell, darkened
    n = int(SR * 2.0); t = np.arange(n) / SR
    y = lowpass(highpass(rng.standard_normal(n), 3000), 7000) * np.exp(-t * 2.2)
    return y * env(n, 0.002, 0.2) * 0.12


# ------------------------------------------------------------------ render
class Loop(Track):
    def render(self, path, reverb=2.4, cutoff=6000.0, rms_db=-21.0):
        m = int(SR * reverb); t = np.arange(m) / SR; out = self.dry.copy()
        for c in range(2):
            ir = rng.standard_normal(m) * np.exp(-t * 6.9 / reverb)
            ir = np.convolve(ir, np.ones(24) / 24, 'same'); ir[:int(0.015 * SR)] = 0
            ir /= np.sqrt((ir ** 2).sum())
            pad_ir = np.zeros(self.n); pad_ir[:m] = ir
            out[:, c] += np.fft.irfft(np.fft.rfft(self.wet[:, c]) * np.fft.rfft(pad_ir), self.n)
        # roll off the top (filter three loops' worth, keep the middle one: seamless)
        big = np.concatenate([out, out, out])
        for c in range(2):
            big[:, c] = lowpass(highpass(big[:, c], 32), cutoff, 2)
        out = big[self.n:2 * self.n]
        out *= 10 ** (rms_db / 20) / np.sqrt((out ** 2).mean())
        out = np.tanh(out * 1.6) / 1.6                     # gentle peak limit
        with wave.open(path + '.wav', 'wb') as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((np.clip(out, -1, 1) * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path + '.wav', '-c:a', 'libvorbis',
                        '-q:a', '4', path + '.ogg'], check=True)
        os.remove(path + '.wav')
        print(path, round(self.n / SR, 1), 's')


def chord(tr, inst, beat, dur, notes, vol, pan=0.0, send=0.3, spread=0.0):
    for i, nt in enumerate(notes):
        p = pan + spread * (i / max(len(notes) - 1, 1) - 0.5)
        tr.add(inst, beat, dur, nf(nt), vol, p, send)


# -------------------------------------------------------------------- city
CITY_A = [  # (bass root, voicing), two bars each
    ('F2', ['Ab3', 'C4', 'Eb4', 'G4']),       # Fm9
    ('Db2', ['F3', 'Ab3', 'C4', 'Eb4']),      # Dbmaj9
    ('Bb1', ['Ab3', 'Db4', 'F4', 'C5']),      # Bbm11
    ('C2', ['Bb3', 'E4', 'G4', 'Db5']),       # C7b9
]
CITY_B = [
    ('Db2', ['F3', 'Ab3', 'C4', 'Eb4']),      # Dbmaj9
    ('Eb2', ['G3', 'Bb3', 'Db4', 'F4']),      # Eb9
    ('Ab1', ['G3', 'C4', 'Eb4', 'Bb4']),      # Abmaj9
    ('Gb1', ['F3', 'Bb3', 'C4', 'Eb4']),      # Gbmaj7#11 (that lifted, dreamy colour)
    ('F2', ['Ab3', 'C4', 'Eb4', 'G4']),       # Fm9
    ('Db2', ['F3', 'Ab3', 'C4', 'Eb4']),
    ('Bb1', ['Ab3', 'Db4', 'F4', 'C5']),
    ('C2', ['Bb3', 'E4', 'G4', 'Db5']),
]
# an original lazy tune over the B section, F minor pentatonic + colour notes: (beat, note, beats)
CITY_TUNE = [(1.5, 'C5', 1), (2.5, 'Eb5', 0.5), (3, 'F5', 2.5), (6, 'Eb5', .5), (6.5, 'C5', 1.5),
             (9.5, 'Bb4', .5), (10, 'C5', 1), (11, 'Eb5', 1), (12, 'G5', 3),
             (17.5, 'Ab5', .5), (18, 'G5', 1), (19, 'F5', 1), (20, 'Eb5', 2), (22.5, 'C5', 1.5),
             (25, 'Bb4', .5), (25.5, 'C5', .5), (26, 'Eb5', 1.5), (27.5, 'Db5', .5), (28, 'C5', 4),
             (33.5, 'C5', 1), (34.5, 'Eb5', .5), (35, 'F5', 2), (37, 'G5', 1), (38, 'Ab5', 2),
             (41.5, 'G5', .5), (42, 'F5', 1), (43, 'Eb5', 1), (44, 'F5', 3),
             (49.5, 'Eb5', .5), (50, 'Db5', 1), (51, 'C5', 1), (52, 'Bb4', 1.5), (53.5, 'Ab4', .5),
             (54, 'G4', 1), (55, 'Bb4', 1), (56, 'C5', 5)]


def city():
    tr = Loop(92, 32 * 4)
    prog = [c for c in CITY_A for _ in (0,)] * 2 + CITY_B     # bars 0-15: A A ; 16-31: B
    for i, (root, voicing) in enumerate(prog):
        b0 = i * 8                                           # two bars per chord
        sec_b = i >= 8
        # electric piano: hit on 1, push on the and-of-2, a softer echo in bar two
        chord(tr, epiano, b0, 1.4, voicing, 0.34, pan=-0.15, send=0.35, spread=0.4)
        chord(tr, epiano, b0 + 2.5, 1.2, voicing[1:], 0.22, pan=-0.15, send=0.35, spread=0.4)
        chord(tr, epiano, b0 + 4.5, 2.5, voicing, 0.2, pan=-0.15, send=0.4, spread=0.4)
        if i % 4 == 3:
            chord(tr, epiano, b0 + 7.5, 0.5, voicing[2:], 0.14, pan=-0.1, send=0.4)
        # bass: root, a fifth, a slide back
        r = nf(root); fifth = r * 1.4983
        for beat, fq, d, v in [(0, r, 1.5, 0.75), (1.5, r, 0.5, 0.35), (2.5, fifth, 1, 0.5),
                               (4, r, 1.0, 0.6), (5.5, r * 2, .5, 0.35), (6, fifth, 1, 0.45),
                               (7.5, r * 1.122, .5, 0.3)]:
            tr.add(round_bass, b0 + beat, d, fq, v, 0.0, 0.05)
        # drums: kick 1 + and-of-3 (lazy), brushed backbeat, shaker eighths
        for bar in (0, 4):
            bb = b0 + bar
            if i == 0 and bar == 0:
                continue                                    # a breath at the top of the loop
            tr.add(soft_kick, bb, 1, vol=0.55, send=0.02)
            tr.add(soft_kick, bb + 2.5, 1, vol=0.4, send=0.02)
            if (i + bar) % 3 == 2:
                tr.add(soft_kick, bb + 3.75, 1, vol=0.22, send=0.02)
            tr.add(brush, bb + 1, 1, vol=0.42, pan=0.1, send=0.2)
            tr.add(brush, bb + 3, 1, vol=0.42, pan=0.1, send=0.2)
            tr.add(rim, bb + 3.5, 1, vol=0.18 if bar else 0.0, pan=-0.3, send=0.2)
            for e in range(8):
                swing = 0.08 if e % 2 else 0.0                # a little swing
                tr.add(shaker, bb + e * 0.5 + swing, 0.1, vol=0.5 if e % 2 else 0.3, pan=0.35, send=0.15)
        # warm sustained pad under the B section
        if sec_b:
            chord(tr, cold_pad, b0, 8, [n.replace('3', '4') for n in voicing[:2]], 0.6, send=0.5, spread=0.6)
    for beat, note, d in CITY_TUNE:                          # the tune on vibes, B section only
        tr.add(vibes, 64 + beat, d, nf(note), 0.55, 0.25, 0.45)
    tr.add(vibes, 2.5, 2, nf('C5'), 0.25, 0.3, 0.6)          # little echoes in the A section
    tr.add(vibes, 34.5, 2, nf('Eb5'), 0.22, 0.3, 0.6)
    tr.render('city', reverb=2.2, cutoff=3200.0, rms_db=-21.0)


# -------------------------------------------------------------------- deep
DEEP = [  # two bars each: (bass root, chord tones for the arpeggio, pad notes)
    ('E2', ['E4', 'G4', 'B4', 'F#5'], ['E3', 'B3']),          # Em(add9)
    ('C2', ['C4', 'G4', 'B4', 'E5'], ['C3', 'G3']),           # Cmaj7
    ('G2', ['D4', 'G4', 'B4', 'D5'], ['G2', 'D3']),           # G
    ('D2', ['D4', 'F#4', 'A4', 'E5'], ['D3', 'A3']),          # Dadd9
    ('E2', ['E4', 'G4', 'B4', 'F#5'], ['E3', 'B3']),
    ('C2', ['C4', 'E4', 'G4', 'B4'], ['C3', 'G3']),
    ('A1', ['C4', 'E4', 'A4', 'B4'], ['A2', 'E3']),           # Am(add9)
    ('B1', ['D#4', 'F#4', 'B4', 'A4'], ['B2', 'F#3']),        # B7: the drop further down
]
ARP = [0, 1, 2, 3, 2, 1, 2, 1]
DEEP_TUNE = [(0, 'B4', 3), (3, 'A4', 1), (4, 'G4', 2), (6, 'F#4', 2), (8, 'E4', 4), (13, 'G4', 1),
             (14, 'A4', 2), (16, 'B4', 3), (19, 'D5', 1), (20, 'C5', 4), (24, 'B4', 2), (26, 'A4', 2),
             (28, 'F#4', 4)]


def deep():
    tr = Loop(104, 32 * 4)
    for i in range(16):
        root, arp, padn = DEEP[i % 8]
        b0 = i * 8; full = i >= 8
        for nt in padn:
            tr.add(cold_pad, b0, 8, nf(nt), 0.75, send=0.7)
        tr.add(drone, b0, 8, nf(root), 0.8 if full else 0.6, send=0.2)
        # the kalimba picks through the chord; it thins out on a dark bar
        for e in range(16):
            if not full and e % 4 == 3:
                continue
            if (i * 16 + e) % 23 == 11:
                continue                                     # a missed note now and then: feels played
            nt = arp[ARP[e % 8]]
            fq = nf(nt) * (2 if (full and e % 8 == 7) else 1)
            tr.add(kalimba, b0 + e * 0.5, 0.5, fq, 0.32 if e % 4 == 0 else 0.2,
                   pan=-0.35 + 0.7 * ((e * 3) % 8) / 7, send=0.5)
        if full:
            # a soft heartbeat pulse and a low marimba answering
            for bar in (0, 4):
                tr.add(soft_kick, b0 + bar, 1, vol=0.3, send=0.05)
                tr.add(soft_kick, b0 + bar + 0.75, 1, vol=0.16, send=0.05)
                tr.add(shaker, b0 + bar + 1.5, .1, vol=0.35, pan=0.4, send=0.3)
                tr.add(shaker, b0 + bar + 3.5, .1, vol=0.35, pan=0.4, send=0.3)
            tr.add(round_bass, b0, 3, nf(root), 0.5, send=0.05)
            tr.add(round_bass, b0 + 4, 2, nf(root), 0.35, send=0.05)
            tr.add(round_bass, b0 + 6.5, 1, nf(root) * 1.4983, 0.25, send=0.05)
    for beat, note, d in DEEP_TUNE:                          # marimba tune, low, in the second half
        tr.add(marimba, 64 + beat, d, nf(note) / 2, 0.55, -0.2, 0.5)
        tr.add(marimba, 96 + beat, d, nf(note) / 2, 0.4, 0.2, 0.6)
    for k in range(22):                                      # drips, far off, random places
        beat = rng.uniform(0, 128); fq = rng.uniform(1300, 2400)
        tr.add(drip, beat, 0.2, fq, rng.uniform(0.08, 0.2), rng.uniform(-0.9, 0.9), 0.9)
    tr.render('deep', reverb=3.8, cutoff=4200.0, rms_db=-23.0)


# ------------------------------------------------------------------- beast
E = 'E'
OST = ['E2', 'E2', 'F2', 'E2', 'G2', 'E2', 'F2', 'E2']        # phrygian ostinato (eighths)
OST2 = ['E2', 'E2', 'B2', 'E2', 'C3', 'B2', 'F2', 'E2']
HORN = [  # the theme, original: (beat, note, beats) over 8 bars
    (0, 'E4', 1.5), (1.5, 'F4', .5), (2, 'G4', 1), (3, 'A4', 1), (4, 'B4', 3), (7, 'C5', 1),
    (8, 'B4', 1.5), (9.5, 'A4', .5), (10, 'G4', 1), (11, 'F4', 1), (12, 'E4', 4),
    (16, 'E4', 1.5), (17.5, 'F4', .5), (18, 'G4', 1), (19, 'B4', 1), (20, 'C5', 2), (22, 'D5', 2),
    (24, 'E5', 1.5), (25.5, 'D5', .5), (26, 'C5', 1), (27, 'B4', 1), (28, 'F4', 2), (30, 'E4', 2)]
CHORDS = [['E3', 'G3', 'B3'], ['F3', 'A3', 'C4'], ['G3', 'B3', 'D4'], ['F3', 'A3', 'C4'],
          ['E3', 'G3', 'B3'], ['D3', 'F3', 'A3'], ['C3', 'E3', 'G3'], ['B2', 'F3', 'B3']]


def beast():
    tr = Loop(160, 40 * 4)
    # 0-7 A: ostinato + drums; 8-15 B: horn theme; 16-23 C: pedal, tension, build;
    # 24-31 D: theme up an octave, full; 32-39 E: the ostinato section again, harder
    for bar in range(40):
        b = bar * 4; sec = bar // 8
        ch = CHORDS[bar % 8]
        ost = OST2 if sec in (2, 4) and bar % 2 else OST
        # string ostinato (two octaves), accents on 1 and the and-of-2
        for e in range(8):
            if sec == 2:
                nt = 'E2'                                     # pedal
            else:
                nt = ost[e]
            acc = 0.9 if e in (0, 3, 6) else 0.6
            tr.add(spicc, b + e * 0.5, 0.5, nf(nt), acc, -0.25, 0.2)
            tr.add(spicc, b + e * 0.5, 0.5, nf(nt) * 2, acc * 0.6, 0.25, 0.2)
        # bass
        root = nf('E1') if sec == 2 else nf(ch[0]) / 2
        if sec in (0, 4):
            root = nf('E1')
        for e, v in [(0, 0.8), (1.5, 0.5), (3, 0.6)]:
            tr.add(round_bass, b + e, 1, root, v, 0.0, 0.03)
        # sustained strings over the theme sections
        if sec in (1, 3):
            chord(tr, strings, b, 4, ch, 0.9 if sec == 3 else 0.7, send=0.4, spread=0.8)
        if sec == 2:                                          # rising tension: a cluster creeping up
            top = ['B3', 'C4', 'C4', 'D4', 'D4', 'D#4', 'E4', 'F4'][bar % 8]
            chord(tr, strings, b, 4, ['E3', top], 0.6 + 0.05 * (bar % 8), send=0.5, spread=0.6)
        # brass stabs on the A / E sections
        if sec in (0, 4) and bar % 2 == 1:
            chord(tr, brass, b + 2.5, 0.5, ['E3', 'G3', 'B3'], 0.7, send=0.3, spread=0.5)
            chord(tr, brass, b + 3.5, 0.5, ['F3', 'A3', 'C4'], 0.8, send=0.3, spread=0.5)
        if sec == 2 and bar % 8 >= 6:
            for e in range(4):
                chord(tr, brass, b + e, 0.4, ['E3', 'F3', 'B3'], 0.5 + 0.1 * e, send=0.3, spread=0.4)
        # drums
        tr.add(taiko, b, 1, vol=0.75, send=0.15)
        if sec != 2 or bar % 8 >= 4:
            tr.add(taiko, b + 1.5, 1, vol=0.45, pan=-0.2, send=0.15)
        tr.add(taiko, b + 2.5, 1, vol=0.55, pan=0.2, send=0.15)
        if sec != 2:
            tr.add(kick, b, 1, vol=0.55, send=0.02)
            tr.add(kick, b + 2, 1, vol=0.45, send=0.02)
            tr.add(snare_hit, b + 1, 1, vol=0.35, pan=0.1, send=0.2)
            tr.add(snare_hit, b + 3, 1, vol=0.38, pan=0.1, send=0.2)
            for e in range(8):
                tr.add(hat, b + e * 0.5, .1, vol=0.07 if e % 2 else 0.04, pan=0.3, send=0.05)
        else:                                                # toms rolling up into D
            k = bar % 8
            for e in range(2 if k < 4 else (4 if k < 7 else 8)):
                step = 4 / (2 if k < 4 else (4 if k < 7 else 8))
                tr.add(tom, b + e * step, .5, 90 + 12 * e + 6 * k, 0.4 + 0.04 * k, pan=-0.4 + 0.1 * e, send=0.2)
            for e in range(4):                               # the hats keep time through the tension
                tr.add(hat, b + e + 0.5, .1, vol=0.05 + 0.005 * k, pan=0.3, send=0.05)
        if bar % 8 == 0 and bar > 0:
            tr.add(crash, b, 1, vol=1.0, pan=0.2, send=0.3)
    for beat, note, d in HORN:                               # the theme: horns (B), horns up an octave + strings (D)
        tr.add(brass, 32 + beat, d, nf(note), 1.0, -0.1, 0.35)
        tr.add(brass, 32 + beat, d, nf(note) / 2, 0.5, 0.1, 0.35)
        tr.add(brass, 96 + beat, d, nf(note), 0.9, -0.1, 0.35)
        tr.add(strings, 96 + beat, d, nf(note) * 2, 0.7, 0.25, 0.35)
        tr.add(brass, 96 + beat, d, nf(note) / 2, 0.55, 0.1, 0.35)
    tr.render('beast', reverb=1.7, cutoff=7500.0, rms_db=-19.5)


if __name__ == '__main__':
    for f in (city, deep, beast):
        if len(sys.argv) < 2 or f.__name__ in sys.argv:
            f()
