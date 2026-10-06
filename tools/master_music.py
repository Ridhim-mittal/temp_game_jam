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
}


def load(path, pitch=0.0):
	if pitch:  # rubberband: pitch only, the tempo stays
		tmp = os.path.join(OUT, "_pitched.wav")
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-af",
						f"rubberband=pitch={2 ** (pitch / 12):.6f}:pitchq=quality", tmp], check=True)
		path = tmp
	y, _ = librosa.load(path, sr=SR, mono=False)
	if pitch:
		os.remove(path)
	return y if y.ndim == 2 else np.stack([y, y])


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
	x = load(os.path.join(SRC, t["src"]), t.get("pitch", 0.0))
	slack = t.get("slack")
	if "breath" in t:
		s_smp, e_smp = breath_points(x.mean(0), t["breath"]); score = 1.0
	elif slack is None:
		s_smp, e_smp, score = int(t["s"] * SR), int((t["s"] + t["length"]) * SR), 1.0
	else:
		s_smp, e_smp, score = find_end(x.mean(0), t["s"], t["length"], slack)
	x = sosfilt(butter(2, 28.0, "high", fs=SR, output="sos"), x, axis=-1)
	x = shelf_cut(x, t.get("top", 0.0), t.get("top_fc", 7000.0))
	if t.get("verb", 0.0):
		x = cavern(x, t["verb"])
	lufs = t["lufs"]
	out = x[:, :e_smp].copy()
	n = int((XFADE if slack is not None else 0.4) * SR)
	k = np.linspace(0, np.pi / 2, n)
	out[:, -n:] = out[:, -n:] * np.cos(k) + x[:, s_smp - n:s_smp] * np.sin(k)  # end runs into S
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
