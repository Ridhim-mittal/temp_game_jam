import numpy as np, wave, subprocess, sys
SR = 44100
rng = np.random.default_rng(7)
SCALE = [0, 2, 4, 5, 7, 9, 11]
def deg(d):            # scale degree (0 = C4) -> frequency
    return 440.0 * 2 ** ((60 + 12 * (d // 7) + SCALE[d % 7] - 69) / 12)
NOTE = {n: i for i, n in enumerate(['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'])}
def nf(name):          # "A3" -> frequency
    return 440.0 * 2 ** ((NOTE[name[:-1]] + 12 * (int(name[-1]) + 1) - 69) / 12)

def env(n, a, r):
    e = np.ones(n); na = max(int(a * SR), 1); nr = max(int(r * SR), 1)
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e

def box(f, dur):       # music box
    n = int(SR * max(dur, 0.6) + SR * 2.0); t = np.arange(n) / SR
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d)
            for r, a, d in [(1, 1, 2.6), (2, .45, 4.5), (3.01, .2, 7), (4.2, .1, 11), (6.3, .05, 16)])
    return y * env(n, 0.002, 0.05)

def piano(f, dur):     # soft felt piano
    n = int(SR * (dur + 1.6)); t = np.arange(n) / SR; y = np.zeros(n)
    for k in range(1, 7):
        for det in (0.9985, 1.0015):
            y += (1 / k ** 1.6) * np.sin(2 * np.pi * f * k * det * t) * np.exp(-t * (1.1 + 0.7 * k))
    rel = np.ones(n); nd = int(dur * SR); rel[nd:] = np.exp(-np.arange(n - nd) / SR * 5)
    return y * rel * env(n, 0.006, 0.05) * 0.5

def pad(f, dur):       # warm slow pad
    n = int(SR * (dur + 1.5)); t = np.arange(n) / SR; y = np.zeros(n)
    for det in (0.994, 1.0, 1.006):
        y += np.sin(2 * np.pi * f * det * t + rng.uniform(0, 6)) + 0.25 * np.sin(4 * np.pi * f * det * t)
    y *= 1 + 0.12 * np.sin(2 * np.pi * 0.3 * t)
    return y * env(n, min(0.9, dur * 0.4), 1.4) * 0.22

def bass(f, dur):
    n = int(SR * (dur + 0.3)); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) + 0.1 * np.sin(6 * np.pi * f * t)
    return y * np.exp(-t * 1.6) * env(n, 0.006, 0.2) * 0.9

def pluck(f, dur):     # muted pluck for the boss ostinato
    n = int(SR * 0.5); t = np.arange(n) / SR
    y = sum((1 / k ** 2) * np.sin(2 * np.pi * f * k * t) for k in (1, 3, 5, 7))
    return y * np.exp(-t * 10) * env(n, 0.003, 0.05)

def kick(f=0, dur=0):
    n = int(SR * 0.45); t = np.arange(n) / SR
    ph = 2 * np.pi * (46 * t + 70 / 28 * (1 - np.exp(-28 * t)))
    return np.sin(ph) * np.exp(-t * 9) * env(n, 0.002, 0.05)

def hat(f=0, dur=0):
    n = int(SR * 0.09); y = np.diff(rng.standard_normal(n + 1)); t = np.arange(n) / SR
    return y * np.exp(-t * 55) * 0.5

def snare(f=0, dur=0):
    n = int(SR * 0.3); t = np.arange(n) / SR
    y = rng.standard_normal(n) * np.exp(-t * 22) * 0.6 + np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30)
    return y * env(n, 0.001, 0.05)

class Track:
    def __init__(self, bpm, beats, loop=True, tail=0.0):
        self.spb = 60.0 / bpm; self.loop = loop
        self.n = int(round(beats * self.spb * SR)) + int(tail * SR)
        self.dry = np.zeros((self.n, 2)); self.wet = np.zeros((self.n, 2))
    def add(self, inst, beat, dur_beats, freq=0.0, vol=1.0, pan=0.0, send=0.3):
        y = inst(freq, dur_beats * self.spb) * vol
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        st = np.stack([y * l, y * r], 1); i0 = int(round(beat * self.spb * SR))
        idx = np.arange(i0, i0 + len(y))
        if self.loop: idx %= self.n            # tails wrap round: seamless loop
        else:
            keep = idx < self.n; idx = idx[keep]; st = st[keep]
        np.add.at(self.dry, idx, st); np.add.at(self.wet, idx, st * send)
    def render(self, path, reverb=2.4, fade_out=0.0):
        m = int(SR * reverb); t = np.arange(m) / SR; out = self.dry.copy()
        for c in range(2):
            ir = rng.standard_normal(m) * np.exp(-t * 6.9 / reverb)
            ir = np.convolve(ir, np.ones(24) / 24, 'same'); ir[:int(0.012 * SR)] = 0
            ir /= np.sqrt((ir ** 2).sum())
            if self.loop:                      # circular convolution keeps the loop seamless
                pad_ir = np.zeros(self.n); pad_ir[:m] = ir
                out[:, c] += np.fft.irfft(np.fft.rfft(self.wet[:, c]) * np.fft.rfft(pad_ir), self.n)
            else:
                from scipy.signal import fftconvolve; out[:, c] += fftconvolve(self.wet[:, c], ir)[:self.n]
        out /= np.abs(out).max() / 0.85
        out = np.tanh(out * 1.15) / np.tanh(1.15) * 0.82
        if fade_out:
            k = int(fade_out * SR); out[-k:] *= np.linspace(1, 0, k)[:, None] ** 2
        with wave.open(path + '.wav', 'wb') as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes((out * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path + '.wav', '-c:a', 'libvorbis', '-q:a', '5', path + '.ogg'], check=True)
        print(path, round(self.n / SR, 1), 's')

# ---------------------------------------------------------------- the theme
# Vesper's motif, 8 bars of 4 beats, as (scale degree, beats). Degree 0 = C4.
MOTIF = [[(9, 1), (11, 1), (14, 1.5), (13, .5)], [(12, 1), (9, 1), (12, 2)],
         [(10, 1), (12, 1), (14, 1.5), (12, .5)], [(11, 1), (8, 1), (11, 2)],
         [(9, 1), (11, 1), (14, 1.5), (15, .5)], [(16, 1), (14, 1), (12, 2)],
         [(10, 1), (12, 1), (11, 1), (13, 1)], [(14, 4)]]
MAJOR = [['C3', 'E3', 'G3'], ['A2', 'C3', 'E3'], ['F2', 'A2', 'C3'], ['G2', 'B2', 'D3'],
         ['C3', 'E3', 'G3'], ['A2', 'C3', 'E3'], ['G2', 'B2', 'D3'], ['C3', 'E3', 'G3']]
MINOR = [['A2', 'C3', 'E3'], ['F2', 'A2', 'C3'], ['D3', 'F3', 'A3'], ['E2', 'G2', 'B2'],
         ['A2', 'C3', 'E3'], ['F2', 'A2', 'C3'], ['D3', 'F3', 'A3'], ['A2', 'C3', 'E3']]

def melody(tr, inst, start_bar, shift=0, octave=0, vol=1.0, pan=0.0, send=0.35, stretch=1.0, bars=range(8)):
    for b in bars:
        beat = (start_bar + b) * 4 * stretch
        for d, dur in MOTIF[b]:
            tr.add(inst, beat, dur * stretch, deg(d + shift + 7 * octave), vol, pan, send)
            beat += dur * stretch

def lit_pages():      # warm and curious: music box over a slow pad
    tr = Track(92, 64)
    for rep in range(2):
        for b in range(8):
            bar = rep * 8 + b; ch = MAJOR[b]
            for n in ch: tr.add(pad, bar * 4, 4, nf(n) * 2, 0.5, send=0.5)
            if rep == 1:
                tr.add(bass, bar * 4, 2, nf(ch[0]), 0.6); tr.add(bass, bar * 4 + 2.5, 1, nf(ch[0]), 0.35)
                for i, k in enumerate([0, 1, 2, 1, 0, 1, 2, 1]):      # gentle piano arpeggio
                    tr.add(piano, bar * 4 + i * .5, .5, nf(ch[k]) * 2, 0.28, pan=0.35, send=0.4)
        melody(tr, box, rep * 8, vol=0.55, pan=-0.15, send=0.45)
        if rep == 1: melody(tr, box, 8, octave=-1, vol=0.22, pan=0.4, send=0.5)
    tr.render('lit_pages')

def margins():        # the same tune, minor, slow and far away, over a dark drone
    tr = Track(66, 64)
    for b in range(16):
        ch = MINOR[b % 8]
        tr.add(pad, b * 4, 4, nf(ch[0]), 0.9, send=0.6); tr.add(pad, b * 4, 4, nf(ch[0]) * 1.5, 0.35, send=0.6)
        tr.add(pad, b * 4, 4, nf(ch[1]) * 2, 0.3, pan=0.3, send=0.6)
        tr.add(bass, b * 4, 4, nf(ch[0]) / 2, 0.75, send=0.1)
        if b % 2 == 1: tr.add(box, b * 4 + 3, 1, nf(ch[2]) * 8, 0.1, pan=0.6, send=0.9)   # distant chime
    melody(tr, box, 8, shift=-2, vol=0.42, pan=-0.2, send=0.8)
    melody(tr, box, 8, shift=-2, octave=-1, vol=0.16, pan=0.5, send=0.9, bars=[1, 3, 5, 7])
    for b in (0, 2, 4, 6):                                  # fragments of the tune before it arrives
        d, _ = MOTIF[b][0]; tr.add(box, b * 4 + 2, 2, deg(d - 2), 0.22, pan=-0.4, send=0.9)
    tr.render('margins', reverb=3.6)

def shade_boss():     # driving minor ostinato, motif on piano
    tr = Track(138, 64)
    prog = [MINOR[0], MINOR[0], MINOR[1], MINOR[1], MINOR[2], MINOR[2], MINOR[3], MINOR[3]]
    for b in range(16):
        ch = prog[b % 8]; root = nf(ch[0])
        for n in ch: tr.add(pad, b * 4, 4, nf(n) * 2, 0.35, send=0.4)
        for i in range(8):
            tr.add(bass, b * 4 + i * .5, .5, root if i % 4 else root / 2, 0.55 if i % 2 == 0 else 0.35, send=0.05)
            tr.add(pluck, b * 4 + i * .5, .5, nf(ch[[0, 2, 1, 2, 0, 2, 1, 2][i]]) * 4, 0.3, pan=0.4 if i % 2 else -0.4, send=0.3)
            tr.add(hat, b * 4 + i * .5, .1, vol=0.07 if i % 2 else 0.04, pan=0.25, send=0.1)
        for beat in (0, 2, 2.5 if b % 2 else 2): tr.add(kick, b * 4 + beat, 1, vol=0.9, send=0.03)
        tr.add(snare, b * 4 + 1, 1, vol=0.3, send=0.25); tr.add(snare, b * 4 + 3, 1, vol=0.3, send=0.25)
    melody(tr, piano, 8, shift=-2, vol=0.75, pan=-0.1, send=0.4, stretch=1.0)
    melody(tr, piano, 0, shift=-2, octave=-1, vol=0.4, send=0.4, bars=[0, 2, 4, 6])
    tr.render('shade_boss', reverb=1.6)

def ending():         # the opening tune again, slow, on piano: a goodbye
    tr = Track(60, 88, loop=False, tail=6.0)
    for rep in range(2):
        for b in range(8):
            bar = rep * 8 + b; ch = MAJOR[b]; last = rep == 1 and b == 7
            for n in ch: tr.add(pad, bar * 4, 8 if last else 4, nf(n) * 2, 0.4 + 0.15 * rep, send=0.6)
            tr.add(piano, bar * 4, 4, nf(ch[0]), 0.5, send=0.4)
            if rep == 1 and not last:
                for i, k in enumerate([0, 1, 2, 1]):
                    tr.add(piano, bar * 4 + i, 1, nf(ch[k]) * 2, 0.22, pan=0.3, send=0.5)
        melody(tr, piano, rep * 8, vol=0.7, pan=-0.1, send=0.5)
        if rep == 1: melody(tr, box, 8, octave=1, vol=0.16, pan=0.35, send=0.8)
    for i, d in enumerate([14, 16, 18, 21]):               # last chord rolls upward into the light
        tr.add(box, 64 + 4 + i * 1.5, 4, deg(d), 0.3, pan=-0.3 + 0.2 * i, send=0.8)
    tr.render('ending', reverb=3.4, fade_out=5.0)

if __name__ == '__main__':
  for f in (lit_pages, margins, shade_boss, ending):
    if len(sys.argv) < 2 or f.__name__ in sys.argv: f()
