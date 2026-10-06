extends RefCounted
## Sound effects synthesised in code (the project has no effect audio files),
## made once and cached: the Scribbled Beast and its cutscenes use them.
##
##   SfxSynth.play(tree, "roar", -2.0)
##
## Names: roar, rumble, rip, clang, scritch, splut, thud, screech, whoosh,
## shatter.

const RATE := 22050

static var _cache := {}


static func play(tree: SceneTree, sound: String, db := 0.0, pitch := 1.0) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = get_stream(sound)
	p.volume_db = db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func get_stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _make(sound)
	return _cache[sound]


static func _make(sound: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = sound.hash()
	var dur := {"roar": 2.2, "rumble": 2.6, "rip": 0.7, "clang": 0.5, "scritch": 0.35, "splut": 0.3,
		"thud": 0.6, "screech": 1.6, "whoosh": 0.45, "shatter": 1.2}.get(sound, 0.5) as float
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	var phase2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var noise := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match sound:
			"roar":
				# a low growl swelling into a ragged roar: saw-ish voice + rough noise
				var env := minf(t / 0.25, 1.0) * (1.0 - smoothstep(0.65, 1.0, k))
				var f := 70.0 + 55.0 * sin(k * PI) + 6.0 * sin(t * 37.0)
				phase += f / RATE
				var voice := fmod(phase, 1.0) * 2.0 - 1.0
				phase2 += f * 1.51 / RATE
				var voice2 := fmod(phase2, 1.0) * 2.0 - 1.0
				lp = lerpf(lp, noise, 0.18)
				v = (voice * 0.45 + voice2 * 0.25 + lp * 0.9 * (0.6 + 0.4 * sin(t * 61.0))) * env
			"rumble":
				lp = lerpf(lp, noise, 0.02)
				lp2 = lerpf(lp2, noise, 0.06)
				var env := smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.7, 1.0, k))
				v = (lp * 6.0 + lp2 * 1.2 + sin(TAU * 38.0 * t) * 0.3) * env
			"rip":
				# paper tearing: crackly noise bursts
				var crack := 1.0 if rng.randf() < 0.25 + 0.5 * sin(k * PI) else 0.3
				lp = lerpf(lp, noise, 0.6)
				v = lp * crack * (1.0 - k) * 0.9
			"clang":
				var env := exp(-t * 9.0)
				v = (sin(TAU * 520.0 * t) * 0.5 + sin(TAU * 1310.0 * t) * 0.3 + sin(TAU * 2270.0 * t) * 0.2 + noise * 0.3 * exp(-t * 40.0)) * env
			"scritch":
				lp = lerpf(lp, noise, 0.7)
				v = lp * (0.5 + 0.5 * sin(TAU * 45.0 * t)) * (1.0 - k)
			"splut":
				lp = lerpf(lp, noise, 0.12)
				v = (lp * 2.2 + sin(TAU * (180.0 - 120.0 * k) * t) * 0.5) * exp(-t * 14.0)
			"thud":
				lp = lerpf(lp, noise, 0.05)
				v = (sin(TAU * (65.0 - 25.0 * k) * t) * 0.9 + lp * 2.0) * exp(-t * 7.0)
			"screech":
				var env := minf(t / 0.05, 1.0) * (1.0 - smoothstep(0.5, 1.0, k))
				var f := 900.0 + 700.0 * sin(t * 5.0) - 500.0 * k
				phase += f / RATE
				lp = lerpf(lp, noise, 0.5)
				v = (sin(TAU * phase + 3.0 * sin(TAU * 73.0 * t)) * 0.4 + lp * 0.5) * env
			"whoosh":
				var cut := 0.05 + 0.5 * sin(k * PI)
				lp = lerpf(lp, noise, cut)
				v = lp * sin(k * PI) * 1.2
			"shatter":
				lp = lerpf(lp, noise, 0.8)
				var tink := sin(TAU * (2400.0 + 900.0 * sin(t * 23.0)) * t) * (1.0 if rng.randf() < 0.08 else 0.0)
				v = (lp * exp(-t * 5.0) + tink * exp(-t * 2.0)) * 0.9
		out[i] = clampf(v * minf(t / 0.003, 1.0), -1.0, 1.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(out[i] * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
