extends SceneTree
## Bakes every sound the game makes in code into assets/sfx/synth/*.wav, so
## nothing is built sample by sample while playing (SfxSynth.baked() loads
## them; the code stays as the fallback). Re-run after changing a sound:
##   godot --headless --path . -s res://tools/sfx/bake_synth.gd
## then let the editor (or `godot --headless --import`) import the files.

const SfxSynth = preload("res://scripts/effects/sfx_synth.gd")
const OUT := "res://assets/sfx/synth/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var n := 0
	for s in ["roar", "rumble", "rip", "clang", "scritch", "splut", "thud", "screech", "whoosh", "shatter",
			"heal_rise", "heal_chime", "heal_fizzle"]:
		n += _save(SfxSynth._make(s), s)
	var cs = load("res://scripts/cutscenes/cs_book.gd").new()
	var sounds: Dictionary = cs._synth_sounds()
	for k in sounds:
		var w: AudioStreamWAV = sounds[k]
		w.loop_mode = AudioStreamWAV.LOOP_DISABLED  # set again at load (SfxSynth.baked(loops))
		n += _save(w, "cs_" + k)
	cs.free()
	var Scribble = load("res://scripts/clearing/scribble.gd")
	n += _save(Scribble._make_shriek(), "scribble_shriek")
	n += _save(Scribble._make_swipe(), "scribble_swipe")
	n += _save(load("res://scripts/world25/gate.gd")._make_chime(), "gate_chime")
	print("baked %d sounds into %s" % [n, OUT])
	quit()


func _save(w: AudioStreamWAV, name: String) -> int:
	if w == null:
		push_error("no sound: " + name)
		return 0
	w.save_to_wav(OUT + name + ".wav")
	return 1
