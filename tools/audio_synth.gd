class_name AudioSynth
## Tiny offline synthesizer: builds placeholder SFX and looping music as 16-bit mono WAV.
## Used only by tools/generate_audio.gd (never at runtime), so speed does not matter.

const RATE := 22050

enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }


static func buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


static func osc(wave: int, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		Wave.SINE: return sin(p * TAU)
		Wave.SQUARE: return 1.0 if p < 0.5 else -1.0
		Wave.TRIANGLE: return 4.0 * absf(p - 0.5) - 1.0
		Wave.SAW: return 2.0 * p - 1.0
		_: return randf() * 2.0 - 1.0


## Adds a note with an attack/decay envelope. freq_end != freq gives a pitch sweep.
static func note(buf: PackedFloat32Array, start: float, dur: float, freq: float, wave: int, vol: float,
		freq_end := -1.0, attack := 0.005, release := 0.08) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var f1 := freq if freq_end < 0.0 else freq_end
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		var k := float(i) / maxf(1.0, n)
		var env := minf(1.0, t / maxf(attack, 0.0001))
		var tail := dur - t
		if tail < release:
			env *= maxf(0.0, tail / release)
		var f := lerpf(freq, f1, k)
		phase += f / RATE
		buf[idx] += osc(wave, phase) * vol * env


static func midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


## Soft clip + normalise to `peak`, then wrap as AudioStreamWAV (optionally looping).
static func to_wav(buf: PackedFloat32Array, loop := false, peak := 0.85) -> AudioStreamWAV:
	var m := 0.0001
	for v in buf:
		m = maxf(m, absf(v))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var s := clampf(buf[i] / m * peak, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## Music from a step sequence: each row = [melody midi or -1, bass midi or -1] per step.
static func song(steps: Array, step_sec: float, lead: int, bass: int, lead_vol := 0.35, bass_vol := 0.3,
		drums := true) -> PackedFloat32Array:
	var buf := buffer(steps.size() * step_sec)
	for i in steps.size():
		var row: Array = steps[i]
		var t := i * step_sec
		if row[0] >= 0:
			note(buf, t, step_sec * 0.9, midi(row[0]), lead, lead_vol, -1.0, 0.01, step_sec * 0.4)
		if row[1] >= 0:
			note(buf, t, step_sec * 1.8, midi(row[1]), bass, bass_vol, -1.0, 0.01, step_sec * 0.6)
		if drums:
			if i % 4 == 0:
				note(buf, t, 0.12, 110.0, Wave.SINE, 0.5, 40.0) # kick
			elif i % 4 == 2:
				note(buf, t, 0.08, 1.0, Wave.NOISE, 0.12) # hat
	return buf
