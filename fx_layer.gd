class_name FxLayer
extends Control
## Lightweight overlay for gameplay effects: ripples, sparks, confetti, floating text.
## Positions are in this control's local space (it covers the whole screen).

var _rings: Array = []      # {pos, color, r0, r1, t, dur, width}
var _particles: Array = []  # {pos, vel, color, size, t, dur, gravity, rot, spin, rect}
var _texts: Array = []      # {pos, text, color, size, t, dur}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func clear() -> void:
	_rings.clear()
	_particles.clear()
	_texts.clear()
	queue_redraw()

func ring(pos: Vector2, color: Color, r0: float, r1: float, dur := 0.45, width := 4.0) -> void:
	_rings.append({pos = pos, color = color, r0 = r0, r1 = r1, t = 0.0, dur = dur, width = width})

func burst(pos: Vector2, color: Color, count: int, speed := 220.0, size := 4.0) -> void:
	for i in range(count):
		var a := randf() * TAU
		var v := Vector2.from_angle(a) * speed * randf_range(0.4, 1.0)
		_particles.append({pos = pos, vel = v, color = color.lerp(Color.WHITE, randf() * 0.3),
			size = size * randf_range(0.6, 1.3), t = 0.0, dur = randf_range(0.35, 0.6),
			gravity = 420.0, rot = 0.0, spin = 0.0, rect = false})

func confetti(colors: Array, count: int) -> void:
	for i in range(count):
		var pos := Vector2(randf() * size.x, -20.0 - randf() * size.y * 0.4)
		var v := Vector2(randf_range(-60, 60), randf_range(140, 300))
		_particles.append({pos = pos, vel = v, color = colors[i % colors.size()],
			size = randf_range(6.0, 11.0), t = 0.0, dur = randf_range(2.4, 3.6),
			gravity = 60.0, rot = randf() * TAU, spin = randf_range(-6.0, 6.0), rect = true})

func float_text(pos: Vector2, text: String, color: Color, font_size := 34) -> void:
	_texts.append({pos = pos, text = text, color = color, size = font_size, t = 0.0, dur = 1.1})

func _process(delta: float) -> void:
	if _rings.is_empty() and _particles.is_empty() and _texts.is_empty():
		return
	for r in _rings:
		r.t += delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r.t < r.dur)
	for p in _particles:
		p.t += delta
		p.vel.y += p.gravity * delta
		if p.rect:
			p.vel.x += sin(p.t * 3.0 + p.rot) * 40.0 * delta  # flutter
		p.pos += p.vel * delta
		p.rot += p.spin * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p.t < p.dur)
	for t in _texts:
		t.t += delta
	_texts = _texts.filter(func(t: Dictionary) -> bool: return t.t < t.dur)
	queue_redraw()

func _draw() -> void:
	for r in _rings:
		var k: float = r.t / r.dur
		var e := 1.0 - pow(1.0 - k, 3.0)
		var c: Color = r.color
		c.a *= 1.0 - k
		draw_arc(r.pos, lerpf(r.r0, r.r1, e), 0, TAU, 48, c, r.width * (1.0 - k * 0.6), true)
	for p in _particles:
		var k: float = p.t / p.dur
		var c: Color = p.color
		c.a *= 1.0 - k * k
		if p.rect:
			draw_set_transform(p.pos, p.rot, Vector2(1.0, absf(cos(p.t * 5.0 + p.rot))))
			draw_rect(Rect2(-p.size / 2.0, -p.size * 0.3, p.size, p.size * 0.6), c)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(p.pos, p.size * (1.0 - k * 0.5), c, true)
	var font := UITheme.TITLE_FONT
	for t in _texts:
		var k: float = t.t / t.dur
		var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - k * 6.0)  # quick pop at start
		var fs := int(t.size * pop)
		var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var tsz := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos: Vector2 = t.pos + Vector2(-tsz.x / 2.0, -k * 50.0)
		var outline := Color(UITheme.PAPER, a)
		draw_string_outline(font, pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, outline)
		var c: Color = t.color
		c.a = a
		draw_string(font, pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
