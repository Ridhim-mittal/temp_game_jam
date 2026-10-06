"""The story's music: the team's licensed tracks, cut into seamless loops and mastered quiet.

    python3 tools/master_music.py            # all of them
    python3 tools/master_music.py beast      # just one

Sources live in audio/music/src/ (a .gdignore keeps Godot from importing them):
  city    <- cool_down.mp3            THE CITY + the Sketchbook
  deep    <- flicker_in_the_deep.mp3  THE LONG DROP
  beast   <- incisive_battle.mp3      the Scribbled Beast's fight and the Eraser's chase
  repose  <- repose.mp3               the Margins: the Spine (hub) and the Torn Wastes
  silk    <- silksong.mp3             the Margins: the Inkwood
  dread   <- incisive_battle.mp3      the Margins' boss fights (the Red Pen, the Eraser): the
                                      battle two semitones down at the same tempo, its top
                                      rolled off and set far back in a dark, cavernous
                                      reverb, so it drives but stays dark and mysterious
  hunters <- the_hunters.mp3          Shade's part (Shade's City, the Ink Cave, the finale):
                                      quiet, its muddy low mids eased and a little presence
                                      added so it still reads under the sound effects; loops
                                      39 bars, the breakdown leading back into the build
  hand    <- hand_theme.mp3           the finale's waves, while Shade's hand draws the monsters:
                                      from 2:33 on, straight in (no intro), 44 bars looping;
                                      its lead pulled back, darkened, in the cavern reverb,
                                      with the same boss layers as "hunt" on its beat
  duel    <- shade_duel.ogg           the finale's last fight: Shade as Vesper's double
  hunt    <- the_hunters.mp3          the boss fights there (the Ink Blots, Shade): 32 bars
                                      from the driving middle of the same track (its peak,
                                      breakdown and climb back), 8% faster, brighter,
                                      starting straight in on the groove, with tension laid
                                      over it on its own beat grid (TENSION below): a heart-
                                      beat thump on every beat, ticking sixteenths, a
                                      tremolo D / E-flat string cluster swelling over each
                                      8-bar phrase and a riser into a sub hit at each phrase

Each output plays from the top once (the intro), then music.gd loops it from
LOOP_FROM (printed here; copy it into music.gd). The loop point is found by
matching the music: the end E is the place whose sound (chroma + mel spectrum,
a few seconds round it) is most like the loop start S, refined to the sample by
cross-correlation, and the last 90 ms of the file are blended with the 90 ms
before S, so the jump back is inaudible. The clips' fade-outs are cut off.
A track that fades in and out ("breath") loops whole instead, from where its
fade-out drops below a level back to where its fade-in rose past it, quiet into
quiet (a 0.4 s blend).
Mastering: a 28 Hz low cut, the battle's top end eased (it's mastered hot and
gets fatiguing under a long fight), then loudness to a quiet target (LUFS)
with a soft peak limit. music.gd's TRIM / volume_db set the final level.
"""
import os, sys, subprocess
import numpy as np
import librosa, pyloudnorm
from scipy.signal import butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "audio/music/src")
OUT = os.path.join(ROOT, "audio/music")
SR = 44100
XFADE = 0.09

TRACKS = {
	# the song comes round again every 38.4 s: play 0..73 once, then loop its second pass
	"city": dict(src="cool_down.mp3", s=34.78, length=38.4, slack=0.6, lufs=-19.0),
	# a quiet first pass that fades to near silence at ~36 s, then the full arrangement,
	# which fades out at ~79 s: the quiet pass plays once, then the full one loops through
	# its own breath, from where the fade-out drops below -48 dB back to where the first
	# pass's fade crossed it (quiet into quiet; slack None = fixed points, no matching)
	"deep": dict(src="flicker_in_the_deep.mp3", s=36.47, length=80.97 - 36.47, slack=None, lufs=-21.0),
	# nearly the whole fight track: 0..12 s is the opening hit, 12..69 s loops
	"beast": dict(src="incisive_battle.mp3", s=11.89, length=57.6, slack=0.6, lufs=-18.0, top=-2.5),
	# comes round after 54 s: nearly the whole piece loops
	"repose": dict(src="repose.mp3", s=1.37, length=54.0, slack=0.6, lufs=-21.0),
	# fades in from silence and out again: loops whole, through that breath
	"silk": dict(src="silksong.mp3", breath=-45.0, lufs=-21.0),
	"dread": dict(src="incisive_battle.mp3", s=11.89, length=57.6, slack=0.6, lufs=-20.0,
				  pitch=-2.0, top=-6.0, top_fc=3200.0, verb=0.3),
	# 114.04 BPM, beat 0 at 0.166 s (`grid`: found by folding the onset strength
	# on the beat; it holds to +-13 ms through the whole track). Loops are whole
	# bars on that grid: 7.006..89.085 s is 39 bars (beat 13 to 169)
	"hunters": dict(src="the_hunters.mp3", s=7.006, length=82.08, slack=0.03, lufs=-23.0,
					eq=[(380.0, -2.0, 0.9), (2800.0, 2.0, 0.7)], grid=(0.52615, 0.166)),
	# beat 64 to 192: 32 bars (four 8-bar phrases, so the layers loop with it) of
	# the driving middle, the peak, the breakdown and the climb back; no intro
	"hunt": dict(src="the_hunters.mp3", s=33.840, length=67.347, slack=0.03, lufs=-20.5, start="s",
				 tempo=1.08, eq=[(380.0, -2.5, 0.9), (3200.0, 3.5, 0.7), (9000.0, 2.0, 0.7)],
				 grid=(0.52615, 0.166), tension=True),
	# ~75 BPM, beat 0 at 0.07 s: 0..9.69 s (three bars) plays once, then 16 bars
	# loop (beat 12 to 76; the song itself stops dead at ~64.5 s)
	# 120 BPM: from 2:33 (153.03 s, the user's pick), no intro; 44 bars come round
	# to it at 241.02 s (the music matches best there, well before the fade at ~4:25)
	# made to sit in the game rather than sound like the anime it's from: the lead
	# melody in the middle pulled back (mid_eq), the bright top rolled off, a bit
	# more weight down low, set back in the dark cavern, and the boss layers of
	# "hunt" on its own grid (120.0 BPM, beat 0 at 0.011 s; a semitone down, in
	# C-sharp minor, and the D / E-flat cluster comes down with it)
	"hand": dict(src="hand_theme.mp3", s=153.03, length=87.99, slack=0.05, lufs=-19.5, start="s", pitch=-1.0,
				 mid_eq=[(1100.0, -4.0, 0.7), (2600.0, -5.0, 0.8)], eq=[(70.0, 2.0, 0.8), (350.0, -1.5, 0.9)],
				 top=-6.0, top_fc=3800.0, verb=0.22, grid=(0.49993, 0.0111), tension=True),
	"duel": dict(src="shade_duel.ogg", s=9.69, length=51.28, slack=0.04, lufs=-19.5),
}

## The boss layers' levels (relative to the music's own loudness, dB) and the
## cluster's notes (Hz): D4 E-flat4 A4 D5 E-flat5, the track's D minor with
## the half step above the root rubbing against it.
TENSION = dict(thump=-3.0, tick=-29.0, strings=-13.0, riser=-15.0, hit=-5.0,
			   notes=(293.66, 311.13, 440.0, 587.33, 622.25), phrase_bars=8)


def load(path, pitch=0.0, tempo=1.0):
	stretch = pitch or tempo != 1.0
	if stretch:  # rubberband: pitch and tempo apart from each other
		tmp = os.path.join(OUT, "_pitched.wav")
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-af",
						f"rubberband=pitch={2 ** (pitch / 12):.6f}:tempo={tempo:.6f}:pitchq=quality", tmp], check=True)
		path = tmp
	y, _ = librosa.load(path, sr=SR, mono=False)
	if stretch:
		os.remove(path)
	return y if y.ndim == 2 else np.stack([y, y])


def peak_eq(x, f0, gain_db, q):
	"""An RBJ peaking filter: `gain_db` round `f0` Hz."""
	a = 10 ** (gain_db / 40); w = 2 * np.pi * f0 / SR; al = np.sin(w) / (2 * q)
	b = np.array([1 + al * a, -2 * np.cos(w), 1 - al * a])
	den = np.array([1 + al / a, -2 * np.cos(w), 1 - al / a])
	from scipy.signal import lfilter
	return lfilter(b / den[0], den / den[0], x, axis=-1)


def band(sig, lo, hi):
	return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), sig)


def tension(x, period, phase, s_smp, e_smp, pitch=0.0):
	"""The boss layers, on the (stretched) track's beat grid, from the loop start
	S on (none in the intro, if there is one); phrases are counted from S, so
	the loop's end and its start agree. Levels are set against the music's own
	RMS in the loop."""
	t = TENSION
	n = x.shape[1]
	ref = np.sqrt((x[:, s_smp:e_smp] ** 2).mean())
	lvl = lambda db: ref * 10 ** (db / 20)
	rng = np.random.default_rng(11)
	out = np.zeros(n)
	strings = np.zeros(n)
	phrase = t["phrase_bars"] * 4
	k0 = int(np.ceil((s_smp / SR - phase) / period - 1e-6))  # the first beat at or after S
	k = k0 - 4
	while True:
		bt = phase + k * period
		i = int(round(bt * SR))
		if i >= n:
			break
		pos = (k - k0) % phrase  # beat in the phrase (from S)
		if i >= 0 and k >= k0 - 4:
			# heartbeat thump: a sine dropping from 95 Hz to 48 Hz, strong beats louder
			m = int(0.22 * SR); tt = np.arange(m) / SR
			f = 48 + 47 * np.exp(-tt * 30)
			th = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 16) * (1.0 if k % 2 == 0 else 0.6)
			out[i:i + m] += lvl(t["thump"]) * 2.2 * th[:max(0, min(m, n - i))]
			# ticking sixteenths: short bright noise, the off ones softer
			for q in range(4):
				j = i + int(q * period / 4 * SR)
				m2 = int(0.018 * SR)
				if j + m2 >= n:
					continue
				tick = band(rng.standard_normal(m2), 6000, 11000) * np.exp(-np.arange(m2) / SR * 260)
				out[j:j + m2] += lvl(t["tick"]) * 3.0 * tick * (1.0 if q == 0 else 0.55 if q == 2 else 0.35)
			# into each phrase: a noise riser over its last bar, then a sub hit on its downbeat
			if pos == phrase - 4:
				m3 = int(4 * period * SR); tt = np.arange(m3) / SR
				nz = rng.standard_normal(m3)
				rise = np.zeros(m3)
				for c in range(8):  # sweep up through eight bands
					a_, b_ = c * m3 // 8, (c + 1) * m3 // 8
					fc = 400 * 2 ** (c * 0.6)
					rise[a_:b_] = band(nz[a_:b_], fc, min(fc * 2.2, 16000))
				rise *= (tt / tt[-1]) ** 2.5
				out[i:i + m3] += lvl(t["riser"]) * 2.5 * rise[:max(0, min(m3, n - i))]
			if pos == 0 and k > k0 - 4:
				m4 = int(1.4 * SR); tt = np.arange(m4) / SR
				f = 34 + 60 * np.exp(-tt * 9)
				hit = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 3.2)
				hit += band(rng.standard_normal(m4), 80, 900) * np.exp(-tt * 14) * 0.5
				out[i:i + m4] += lvl(t["hit"]) * 2.0 * hit[:max(0, min(m4, n - i))]
		k += 1
	# the string cluster: detuned saws, low-passed, trembling in sixteenths, each
	# phrase swelling from a whisper to full and breaking off at the next
	tt = np.arange(n) / SR
	for f0 in t["notes"]:
		f0 *= 2 ** (pitch / 12)  # the cluster follows the track when it's pitched
		for det in (-0.12, 0.0, 0.12):
			fr = f0 * 2 ** (det / 12)
			strings += 2 * ((tt * fr + rng.random()) % 1.0) - 1
	strings = sosfilt(butter(2, 1800.0, "low", fs=SR, output="sos"), strings)
	strings = sosfilt(butter(2, 160.0, "high", fs=SR, output="sos"), strings)
	beats = (tt - phase) / period
	trem = 0.55 + 0.45 * np.abs(np.sin(np.pi * beats * 2))  # four pulses a beat
	ph = ((beats - k0) % phrase) / phrase  # 0..1 through the phrase
	swell = np.where(tt >= s_smp / SR - 4 * period, 0.25 + 0.75 * ph ** 1.6, 0.0)
	strings *= trem * swell
	strings *= lvl(t["strings"]) / (np.sqrt((strings[s_smp:e_smp] ** 2).mean()) + 1e-9)
	layer = out + strings
	# a little width: the layers slightly apart in the two channels
	return x + np.stack([layer, np.roll(layer, int(0.004 * SR))])


def breath_points(mono, level):
	"""Where the fade-in first rises past `level` dB and the fade-out last drops below it."""
	hop = 441
	r = librosa.feature.rms(y=mono, hop_length=hop, frame_length=2048)[0]
	db = 20 * np.log10(r + 1e-7)
	up = int(np.argmax(db > level))
	down = len(db) - 1 - int(np.argmax(db[::-1] > level))
	return up * hop, down * hop


def cavern(x, wet, seconds=2.8):
	"""A dark, wide reverb (decorrelated noise tails, low-passed, a little pre-delay)."""
	rng = np.random.default_rng(5)
	m = int(seconds * SR); t = np.arange(m) / SR
	out = x * (1.0 - wet * 0.5)
	for c in range(2):
		ir = rng.standard_normal(m) * np.exp(-t * 6.9 / seconds)
		ir = sosfilt(butter(2, 2200.0, "low", fs=SR, output="sos"), ir)
		ir[:int(0.03 * SR)] = 0.0
		ir /= np.sqrt((ir ** 2).sum())
		from scipy.signal import fftconvolve
		out[c] += wet * fftconvolve(x[c], ir)[:x.shape[1]]
	return out


def features(mono, hop):
	c = librosa.feature.chroma_cqt(y=mono, sr=SR, hop_length=hop)
	m = librosa.power_to_db(librosa.feature.melspectrogram(y=mono, sr=SR, hop_length=hop, n_mels=64))
	m = (m - m.mean(1, keepdims=True)) / (m.std(1, keepdims=True) + 1e-6)
	return np.vstack([c * 3.0, m / 4.0])


def find_end(mono, s, length, slack):
	"""The sample E (near s + length) whose surroundings best match those of S."""
	hop = 128; fps = SR / hop
	f = features(mono, hop)
	before, after = int(1.0 * fps), int(3.0 * fps)

	def win(i):
		v = f[:, i - before:i + after].ravel()
		return v / np.linalg.norm(v)

	si = int(s * fps); ws = win(si)
	cands = range(int((s + length - slack) * fps), int((s + length + slack) * fps))
	scores = [float(win(i) @ ws) for i in cands]
	ei = list(cands)[int(np.argmax(scores))]
	e = int(ei * hop)
	# refine to the sample: line up the waveforms just after S and E
	s_smp = int(s * SR); n = int(0.05 * SR); r = int(0.006 * SR)
	ref = mono[s_smp:s_smp + n]
	best = max(range(-r, r + 1), key=lambda d: float(np.dot(ref, mono[e + d:e + d + n])))
	return s_smp, e + best, max(scores)


def shelf_cut(x, db, fc=7000.0):
	if db == 0.0:
		return x
	hi = sosfilt(butter(2, fc, "high", fs=SR, output="sos"), x, axis=-1)
	return x + (10 ** (db / 20) - 1) * hi


def master(name):
	t = TRACKS[name]
	tempo = t.get("tempo", 1.0)
	x = load(os.path.join(SRC, t["src"]), t.get("pitch", 0.0), tempo)
	slack = t.get("slack")
	if "breath" in t:
		s_smp, e_smp = breath_points(x.mean(0), t["breath"]); score = 1.0
	elif slack is None:
		s_smp, e_smp, score = int(t["s"] * SR), int((t["s"] + t["length"]) * SR), 1.0
	else:
		s_smp, e_smp, score = find_end(x.mean(0), t["s"] / tempo, t["length"] / tempo, slack)
	x = sosfilt(butter(2, 28.0, "high", fs=SR, output="sos"), x, axis=-1)
	x = shelf_cut(x, t.get("top", 0.0), t.get("top_fc", 7000.0))
	for f0, g, q in t.get("eq", []):
		x = peak_eq(x, f0, g, q)
	if t.get("mid_eq"):  # EQ on the middle only (where a lead melody sits), the sides untouched
		mid, side = (x[0] + x[1]) * 0.5, (x[0] - x[1]) * 0.5
		for f0, g, q in t["mid_eq"]:
			mid = peak_eq(mid, f0, g, q)
		x = np.stack([mid + side, mid - side])
	if t.get("verb", 0.0):
		x = cavern(x, t["verb"])
	if t.get("tension"):
		period, phase = t["grid"]
		x = tension(x, period / tempo, phase / tempo, s_smp, e_smp, t.get("pitch", 0.0))
	lufs = t["lufs"]
	# "start": "s" = no intro, the file starts on the loop (no fade-in: the loop
	# comes back to its first sample; music.gd's fade covers the first start)
	head = s_smp if t.get("start") == "s" else 0
	out = x[:, head:e_smp].copy()
	n = int((XFADE if slack is not None else 0.4) * SR)
	k = np.linspace(0, np.pi / 2, n)
	out[:, -n:] = out[:, -n:] * np.cos(k) + x[:, s_smp - n:s_smp] * np.sin(k)  # end runs into S
	s_smp -= head
	e_smp -= head
	meter = pyloudnorm.Meter(SR)
	loop = np.concatenate([out[:, s_smp:]] * 2, axis=1)  # measure what's heard most: the loop
	gain = 10 ** ((lufs - meter.integrated_loudness(loop.T)) / 20)
	out *= gain
	out = np.tanh(out * 1.25) / 1.25  # soft peak limit (barely touches a quiet master)
	wav = os.path.join(OUT, name + ".wav")
	import soundfile
	soundfile.write(wav, out.T, SR, subtype="PCM_16")
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6",
					os.path.join(OUT, name + ".ogg")], check=True)
	os.remove(wav)
	print(f'{name}: intro 0..{s_smp / SR:.3f} s, loop {s_smp / SR:.3f}..{e_smp / SR:.3f} s '
		  f'({(e_smp - s_smp) / SR:.2f} s, match {score:.3f})  LOOP_FROM "{name}": {s_smp / SR:.4f}')


if __name__ == "__main__":
	for t in TRACKS:
		if len(sys.argv) < 2 or t in sys.argv:
			master(t)
