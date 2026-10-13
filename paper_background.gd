extends Control
## Animated ink-wash backdrop: paper gradient, layered distant mountains,
## drifting mist and falling petals. Can be tinted toward the active player.

const PETAL_COUNT := 14
const MIST_COUNT := 9

var _time := 0.0
var _tint := Color(1, 1, 1, 0)
var _tint_tween: Tween
var _mist_tex: GradientTexture2D
var _mists: Array = []   # {pos (0..1 normalized), scale, speed, alpha}
var _petals: Array = []  # {pos (px), vel, rot, spin, size, sway}
var _mountains: Array = []  # [PackedVector2Array (normalized), Color]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0))
	_mist_tex = GradientTexture2D.new()
	_mist_tex.gradient = g
	_mist_tex.fill = GradientTexture2D.FILL_RADIAL
	_mist_tex.fill_from = Vector2(0.5, 0.5)
	_mist_tex.fill_to = Vector2(1.0, 0.5)
	_mist_tex.width = 128
	_mist_tex.height = 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in range(MIST_COUNT):
		_mists.append({pos = Vector2(rng.randf(), rng.randf_range(0.45, 0.95)),
			scale = rng.randf_range(0.5, 1.1), speed = rng.randf_range(0.004, 0.012), alpha = rng.randf_range(0.35, 0.8)})
	_build_mountains(rng)
	resized.connect(_reset_petals)

func set_tint(c: Color, strength := 0.07) -> void:
	## Gently wash the background toward a color (e.g. the active player's).
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(self, "_tint", Color(c, strength), 0.6)

func _build_mountains(rng: RandomNumberGenerator) -> void:
	# Three ridges, far (pale) to near (darker), as normalized polylines
	var layers := [[0.62, 0.10, Color(0.42, 0.36, 0.28, 0.07)],
		[0.72, 0.08, Color(0.38, 0.31, 0.22, 0.09)],
		[0.84, 0.06, Color(0.33, 0.26, 0.17, 0.11)]]
	for layer in layers:
		var base: float = layer[0]
		var amp: float = layer[1]
		var pts := PackedVector2Array()
		var ph1 := rng.randf() * TAU
		var ph2 := rng.randf() * TAU
		for k in range(41):
			var x := k / 40.0
			var y := base - amp * (0.6 * sin(x * 7.0 + ph1) + 0.4 * sin(x * 17.0 + ph2)) * (0.6 + 0.4 * sin(x * 3.0))
			pts.append(Vector2(x, y))
		pts.append(Vector2(1, 1))
		pts.append(Vector2(0, 1))
		_mountains.append([pts, layer[2]])

func _reset_petals() -> void:
	_petals.clear()
	for i in range(PETAL_COUNT):
		_petals.append(_new_petal(true))

func _new_petal(anywhere: bool) -> Dictionary:
	return {
		pos = Vector2(randf() * size.x, randf() * size.y if anywhere else -20.0),
		vel = Vector2(randf_range(8, 30), randf_range(18, 40)),
		rot = randf() * TAU, spin = randf_range(-1.5, 1.5),
		size = randf_range(5.0, 9.0), sway = randf() * TAU,
	}

func _process(delta: float) -> void:
	_time += delta
	for m in _mists:
		m.pos.x += m.speed * delta
		if m.pos.x > 1.3:
			m.pos.x = -0.3
	for p in _petals:
		p.pos += (p.vel + Vector2(sin(_time * 1.3 + p.sway) * 18.0, 0)) * delta
		p.rot += p.spin * delta
		if p.pos.y > size.y + 20 or p.pos.x > size.x + 20:
			var np := _new_petal(false)
			p.merge(np, true)
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([UITheme.BG_TOP, UITheme.BG_TOP, UITheme.BG_BOTTOM, UITheme.BG_BOTTOM]))
	# Pale sun
	var sun := Vector2(s.x * 0.8, s.y * 0.2)
	draw_circle(sun, minf(s.x, s.y) * 0.09, Color(0.93, 0.6, 0.4, 0.12), true)
	# Mountains with a slow parallax drift
	for i in range(_mountains.size()):
		var pts: PackedVector2Array = _mountains[i][0]
		var shift := sin(_time * 0.05 + i) * 6.0 * (i + 1)
		var poly := PackedVector2Array()
		for p in pts:
			poly.append(Vector2(p.x * (s.x + 40) - 20 + shift, p.y * s.y))
		draw_colored_polygon(poly, _mountains[i][1])
	# Mist bands
	for m in _mists:
		var w: float = s.x * 0.7 * m.scale
		var h := w * 0.28
		var c := Vector2(m.pos.x * s.x, m.pos.y * s.y)
		draw_texture_rect(_mist_tex, Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h)), false, Color(1, 1, 1, m.alpha))
	# Petals (plum blossom pink)
	for p in _petals:
		draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.55 + 0.45 * absf(sin(_time * 2.0 + p.sway))))
		draw_circle(Vector2.ZERO, p.size, Color(0.9, 0.55, 0.6, 0.45), true)
		draw_set_transform(Vector2.ZERO)
	if _tint.a > 0.001:
		draw_rect(Rect2(Vector2.ZERO, s), _tint)
