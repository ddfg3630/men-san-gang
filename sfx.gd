class_name Sfx
extends Node
## Tiny procedural sound effects (no audio assets needed).
## Usage: $Sfx.play("place"). Respects GameConfig.sound_on.

const RATE := 22050

static var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

func play(sound: String) -> void:
	if not GameConfig.sound_on:
		return
	var stream := _make(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()

static func _make(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStreamWAV
	match sound:
		"place": s = _knock(560.0, 1310.0, 0.13, 38.0, 0.35)
		"select": s = _knock(1250.0, 2400.0, 0.05, 90.0, 0.1)
		"trap": s = _sweep(320.0, 110.0, 0.38, 0.8)
		"yield": s = _notes([659.25, 880.0], 0.11, 0.45)
		"win": s = _notes([523.25, 659.25, 783.99, 1046.5], 0.13, 0.5)
		"draw": s = _notes([523.25, 392.0], 0.18, 0.45)
		_: return null
	_cache[sound] = s
	return s

static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

static func _knock(f1: float, f2: float, dur: float, decay: float, noise: float) -> AudioStreamWAV:
	## Wooden "clack": two damped partials plus a short noise transient.
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f1)
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-t * decay)
		var v := 0.6 * sin(TAU * f1 * t) + 0.3 * sin(TAU * f2 * t)
		v += noise * rng.randf_range(-1.0, 1.0) * exp(-t * decay * 4.0)
		out[i] = v * env * 0.8
	return _to_stream(out)

static func _sweep(f_start: float, f_end: float, dur: float, amp: float) -> AudioStreamWAV:
	## Falling "thunk" for a piece dropping into a jar.
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var f := lerpf(f_start, f_end, t / dur)
		phase += TAU * f / RATE
		var env := minf(t * 200.0, 1.0) * exp(-t * 9.0)
		out[i] = (sin(phase) + 0.25 * sin(phase * 2.0)) * env * amp
	return _to_stream(out)

static func _notes(freqs: Array, step: float, amp: float) -> AudioStreamWAV:
	## Soft marimba-like arpeggio.
	var total := step * freqs.size() + 0.35
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in range(freqs.size()):
		var f: float = freqs[k]
		var start := int(k * step * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var env := minf(t * 300.0, 1.0) * exp(-t * 7.0)
			out[i] += (sin(TAU * f * t) + 0.2 * sin(TAU * f * 4.0 * t) * exp(-t * 30.0)) * env * amp
	return _to_stream(out)
