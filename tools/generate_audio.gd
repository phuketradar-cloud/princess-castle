extends SceneTree
## Generates placeholder SFX + 3 looping music tracks with AudioSynth and the SoundBank.
##   Godot_console.exe --headless --path . --script res://tools/generate_audio.gd
## Output: res://assets/audio/*.res (binary AudioStreamWAV) and res://data/sound_bank.tres.
## Re-running OVERWRITES them; to use real audio, just swap streams in sound_bank.tres.

const W = AudioSynth.Wave
const DIR := "res://assets/audio"


func _init() -> void:
	seed(7) # deterministic noise
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var bank := SoundBank.new()
	var ok := true
	for id in SFX:
		var buf: PackedFloat32Array = SFX[id].call()
		ok = _save(AudioSynth.to_wav(buf, false, 0.8), id, bank.sfx) and ok
	for id in MUSIC:
		var buf: PackedFloat32Array = MUSIC[id].call()
		ok = _save(AudioSynth.to_wav(buf, true, 0.7), "music_" + id, bank.music, id) and ok
	bank.sfx_db = {"click": -6.0, "miss": -4.0, "status": -3.0}
	ok = ResourceSaver.save(bank, "res://data/sound_bank.tres") == OK and ok
	print("generate_audio: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _save(w: AudioStreamWAV, file: String, into: Dictionary, key := "") -> bool:
	var path := "%s/%s.res" % [DIR, file]
	if ResourceSaver.save(w, path) != OK:
		push_error("could not save " + path)
		return false
	into[key if key != "" else file] = load(path)
	return true


static func b(sec: float) -> PackedFloat32Array:
	return AudioSynth.buffer(sec)


var SFX := {
	"click": func():
		var x := b(0.06); AudioSynth.note(x, 0, 0.05, 1200, W.SQUARE, 0.4, 900, 0.001, 0.03); return x,
	"hit": func():
		var x := b(0.18); AudioSynth.note(x, 0, 0.16, 260, W.SQUARE, 0.5, 70); AudioSynth.note(x, 0, 0.1, 1, W.NOISE, 0.5); return x,
	"crit": func():
		var x := b(0.3); AudioSynth.note(x, 0, 0.28, 520, W.SAW, 0.5, 90); AudioSynth.note(x, 0, 0.15, 1, W.NOISE, 0.7)
		AudioSynth.note(x, 0.02, 0.12, 1400, W.SQUARE, 0.25, 700); return x,
	"miss": func():
		var x := b(0.2); AudioSynth.note(x, 0, 0.18, 600, W.SINE, 0.4, 1500); return x,
	"heal": func():
		var x := b(0.5)
		for i in 4: AudioSynth.note(x, i * 0.08, 0.22, AudioSynth.midi(72 + [0, 4, 7, 12][i]), W.TRIANGLE, 0.4)
		return x,
	"shield": func():
		var x := b(0.4); AudioSynth.note(x, 0, 0.38, 330, W.TRIANGLE, 0.5, 660); AudioSynth.note(x, 0, 0.38, 495, W.SINE, 0.3, 990); return x,
	"status": func():
		var x := b(0.3); AudioSynth.note(x, 0, 0.28, 400, W.SQUARE, 0.3, 200); AudioSynth.note(x, 0.05, 0.2, 300, W.SQUARE, 0.2, 150); return x,
	"death": func():
		var x := b(0.6); AudioSynth.note(x, 0, 0.55, 300, W.SAW, 0.45, 40, 0.005, 0.3); AudioSynth.note(x, 0, 0.3, 1, W.NOISE, 0.3); return x,
	"card": func():
		var x := b(0.35); AudioSynth.note(x, 0, 0.3, 500, W.TRIANGLE, 0.4, 1600); AudioSynth.note(x, 0.05, 0.25, 800, W.SINE, 0.3, 2000); return x,
	"victory": func():
		var x := b(1.3)
		var notes := [67, 72, 76, 79, 84]
		for i in notes.size(): AudioSynth.note(x, i * 0.12, 0.5 if i == notes.size() - 1 else 0.14, AudioSynth.midi(notes[i]), W.SQUARE, 0.35)
		AudioSynth.note(x, 0.48, 0.8, AudioSynth.midi(60), W.TRIANGLE, 0.4)
		return x,
	"defeat": func():
		var x := b(1.4)
		var notes := [67, 63, 60, 55]
		for i in notes.size(): AudioSynth.note(x, i * 0.28, 0.45, AudioSynth.midi(notes[i]), W.TRIANGLE, 0.45)
		return x,
	"level_up": func():
		var x := b(0.9)
		for i in 6: AudioSynth.note(x, i * 0.07, 0.25, AudioSynth.midi(72 + [0, 4, 7, 12, 16, 19][i]), W.SQUARE, 0.3)
		AudioSynth.note(x, 0.42, 0.45, AudioSynth.midi(84), W.TRIANGLE, 0.4)
		return x,
	"boss_phase": func():
		var x := b(1.0); AudioSynth.note(x, 0, 0.9, 80, W.SAW, 0.6, 50, 0.01, 0.4); AudioSynth.note(x, 0, 0.9, 120, W.SQUARE, 0.3, 75, 0.01, 0.4)
		AudioSynth.note(x, 0, 0.5, 1, W.NOISE, 0.25); return x,
	"summon": func():
		var x := b(0.5); AudioSynth.note(x, 0, 0.45, 200, W.SINE, 0.5, 900); AudioSynth.note(x, 0.1, 0.35, 300, W.TRIANGLE, 0.3, 1200); return x,
	"reward": func():
		var x := b(0.6)
		for i in 3: AudioSynth.note(x, i * 0.1, 0.3, AudioSynth.midi(79 + [0, 5, 12][i]), W.SINE, 0.45)
		return x,
	"coin": func():
		var x := b(0.3); AudioSynth.note(x, 0, 0.08, 1320, W.SQUARE, 0.3); AudioSynth.note(x, 0.07, 0.2, 1760, W.SQUARE, 0.3); return x,
	"unlock": func():
		var x := b(1.0)
		for i in 4: AudioSynth.note(x, i * 0.15, 0.5, AudioSynth.midi([60, 64, 67, 72][i]), W.TRIANGLE, 0.35)
		return x,
	"error": func():
		var x := b(0.25); AudioSynth.note(x, 0, 0.1, 180, W.SQUARE, 0.35); AudioSynth.note(x, 0.12, 0.1, 140, W.SQUARE, 0.35); return x,
}

## Step patterns: [lead, bass]; -1 = rest. Built from short chord progressions.
var MUSIC := {
	"castle": func():
		var steps := []
		var chords := [[60, 48], [57, 45], [65, 53], [67, 55]] # C Am F G
		for bar in 8:
			var c: Array = chords[bar % 4]
			var mel := [c[0] + 12, c[0] + 16, c[0] + 19, c[0] + 16, c[0] + 12, -1, c[0] + 14, -1] if bar % 2 == 0 else [c[0] + 19, -1, c[0] + 16, c[0] + 14, c[0] + 12, -1, -1, -1]
			for i in 8:
				steps.append([mel[i], c[1] if i % 4 == 0 else -1])
		return AudioSynth.song(steps, 0.25, W.TRIANGLE, W.SINE, 0.3, 0.35, false),
	"battle": func():
		var steps := []
		var chords := [[57, 45], [53, 41], [55, 43], [52, 40]] # Am F G E
		for bar in 8:
			var c: Array = chords[bar % 4]
			for i in 8:
				var lead: int = [c[0] + 12, -1, c[0] + 15, c[0] + 12, c[0] + 19, -1, c[0] + 17, c[0] + 15][i] if bar % 2 == 0 else [c[0] + 19, c[0] + 17, c[0] + 15, -1, c[0] + 12, c[0] + 15, -1, -1][i]
				steps.append([lead, c[1] if i % 2 == 0 else -1])
		return AudioSynth.song(steps, 0.15, W.SQUARE, W.TRIANGLE, 0.2, 0.4, true),
	"boss": func():
		var steps := []
		var chords := [[50, 38], [46, 34], [48, 36], [49, 37]] # Dm Bb C C#dim
		for bar in 8:
			var c: Array = chords[bar % 4]
			for i in 8:
				var lead: int = [c[0] + 12, c[0] + 13, c[0] + 12, -1, c[0] + 15, -1, c[0] + 12, c[0] + 11][i]
				steps.append([lead if bar >= 2 else -1, c[1]])
		return AudioSynth.song(steps, 0.14, W.SAW, W.SQUARE, 0.18, 0.35, true),
}
