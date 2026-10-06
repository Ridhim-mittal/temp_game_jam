"""The 2D story's music: the team's licensed tracks, cut into seamless loops and mastered quiet.

    python3 tools/master_music.py            # all three
    python3 tools/master_music.py beast      # just one

Sources live in audio/music/src/ (a .gdignore keeps Godot from importing them):
  city   <- cool_down.mp3            THE CITY + the Sketchbook
  deep   <- flicker_in_the_deep.mp3  THE LONG DROP
  beast  <- incisive_battle.mp3      the Scribbled Beast's fight and the Eraser's chase

Each output plays from the top once (the intro), then music.gd loops it from
LOOP_FROM (printed here; copy it into music.gd). The loop point is found by
matching the music: the end E is the place whose sound (chroma + mel spectrum,
a few seconds round it) is most like the loop start S, refined to the sample by
cross-correlation, and the last 90 ms of the file are blended with the 90 ms
before S, so the jump back is inaudible. The clips' fade-outs are cut off.
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

# name: (source, loop start guess S, loop length guess, how far E may move, target LUFS, top-end cut dB)
TRACKS = {
	# the song comes round again every 38.4 s: play 0..73 once, then loop its second pass
	"city": ("cool_down.mp3", 34.78, 38.4, 0.6, -19.0, 0.0),
	# a quiet first pass that fades to near silence at ~36 s, then the full arrangement,
	# which fades out at ~79 s: the quiet pass plays once, then the full one loops through
	# its own breath, from where the fade-out drops below -48 dB back to where the first
	# pass's fade crossed it (quiet into quiet; slack None = fixed points, no matching)
	"deep": ("flicker_in_the_deep.mp3", 36.47, 80.97 - 36.47, None, -21.0, 0.0),
	# nearly the whole fight track: 0..12 s is the opening hit, 12..69 s loops
	"beast": ("incisive_battle.mp3", 11.89, 57.6, 0.6, -18.0, -2.5),
}


def load(path):
	y, _ = librosa.load(path, sr=SR, mono=False)
	return y if y.ndim == 2 else np.stack([y, y])


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
	src, s, length, slack, lufs, top = TRACKS[name]
	x = load(os.path.join(SRC, src))
	if slack is None:
		s_smp, e_smp, score = int(s * SR), int((s + length) * SR), 1.0
	else:
		s_smp, e_smp, score = find_end(x.mean(0), s, length, slack)
	x = sosfilt(butter(2, 28.0, "high", fs=SR, output="sos"), x, axis=-1)
	x = shelf_cut(x, top)
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
