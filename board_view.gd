class_name BoardView
extends Control
## Draws the 悶三缸 board inside its own rect and turns clicks into node indices.
## Purely visual: game rules live in BoardRules, game flow in game.gd.

signal node_clicked(node: int)
signal animation_finished(from_node: int, to_node: int)

# Board geometry in design units (scaled to fit the control).
const DESIGN_SIZE := Vector2(640, 500)
const NODE_OFFSETS: Array[Vector2] = [
	Vector2(-240, -170), Vector2(0, -170), Vector2(240, -170),
	Vector2(-240, 10), Vector2(0, 10), Vector2(240, 10),
	Vector2(-240, 170), Vector2(0, 170), Vector2(240, 170),
]
const EDGES: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 5), Vector2i(3, 6), Vector2i(4, 7),
	Vector2i(5, 8), Vector2i(3, 4), Vector2i(4, 5), Vector2i(6, 7), Vector2i(7, 8),
]
const PIECE_R := 30.0
const JAR_R := 42.0
const DOT_R := 9.0
const HIT_R := 50.0
const ANIM_DURATION := 0.28

## When false the board is a static illustration (main menu).
@export var interactive := true

var _board: Array = BoardRules.make_board()
var _selected := -1
var _targets: Array = []
var _clickable: Array = []
var _hover := -1
var _last_from := -1
var _last_to := -1
var _last_player := -1
var _winner := -1
var _anim: Dictionary = {}  # node -> current draw position
var _tween: Tween = null
var _time := 0.0
var _shake := 0.0

var _scale := 1.0
var _center := Vector2.ZERO
var _positions: Array[Vector2] = []

var _tex_highlight: GradientTexture2D
var _tex_jar: GradientTexture2D
var _tex_glow: GradientTexture2D

# ══════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════

func set_board(board: Array) -> void:
	_board = board.duplicate()
	queue_redraw()

func set_selection(node: int, targets: Array) -> void:
	_selected = node
	_targets = targets.duplicate()
	queue_redraw()

func clear_selection() -> void:
	_selected = -1
	_targets = []
	queue_redraw()

func set_clickable(nodes: Array) -> void:
	## Nodes that react to hover (movable own pieces + valid targets).
	_clickable = nodes.duplicate()
	_update_cursor()
	queue_redraw()

func set_last_move(from: int, to: int, player: int) -> void:
	_last_from = from
	_last_to = to
	_last_player = player
	queue_redraw()

func set_winner(player: int) -> void:
	_winner = player
	queue_redraw()

func animate_piece(from: int, to: int) -> void:
	kill_animation()
	var sp := get_node_pos(from)
	var ep := get_node_pos(to)
	_anim[from] = sp
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		# Slight arc so the piece looks lifted while travelling
		_anim[from] = sp.lerp(ep, t) + Vector2(0, -sin(t * PI) * 14.0 * _scale)
		queue_redraw()
	, 0.0, 1.0, ANIM_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(func() -> void:
		_anim.erase(from)
		_tween = null
		animation_finished.emit(from, to)
	)

func kill_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	_anim.clear()

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func board_scale() -> float:
	return _scale

func get_node_pos(idx: int) -> Vector2:
	if idx < 0 or idx >= _positions.size():
		return Vector2.ZERO
	return _positions[idx]

func hit_test(p: Vector2) -> int:
	var best := -1
	var best_d := HIT_R * _scale
	for i in range(_positions.size()):
		var d := p.distance_to(_positions[i])
		if d < best_d:
			best_d = d
			best = i
	return best

# ══════════════════════════════════════════
#  LIFECYCLE / INPUT
# ══════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_tex_highlight = _radial(Color(1, 1, 1, 0.75), Color(1, 1, 1, 0))
	_tex_jar = _radial(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0))  # depth shading, fades out
	_tex_glow = _radial(Color(UITheme.ACCENT, 0.55), Color(UITheme.ACCENT, 0))
	resized.connect(_compute_layout)
	_compute_layout()

func _process(delta: float) -> void:
	_time += delta
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 30.0, 0.0)
		queue_redraw()
	# Only animate while something pulses
	if _selected >= 0 or not _targets.is_empty() or _winner >= 0 or _hover >= 0:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		var h := hit_test(event.position)
		if h != _hover:
			_hover = h
			_update_cursor()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(hit_test(event.position))
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		_update_cursor()
		queue_redraw()

func _update_cursor() -> void:
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if _clickable.has(_hover) else CURSOR_ARROW

func _compute_layout() -> void:
	_scale = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_center = size / 2.0
	_positions.clear()
	for off in NODE_OFFSETS:
		_positions.append(_center + off * _scale)
	queue_redraw()

static func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t

# ══════════════════════════════════════════
#  DRAWING
# ══════════════════════════════════════════

func _draw() -> void:
	if _positions.is_empty():
		return
	if _shake > 0.0:
		draw_set_transform(Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) * _scale)
	_draw_board_panel()
	_draw_middle_band()
	_draw_lines()
	_draw_jars()
	_draw_dots()
	_draw_last_move()
	_draw_targets()
	_draw_pieces()

func _draw_board_panel() -> void:
	var s := _scale
	var half := DESIGN_SIZE * s / 2.0 - Vector2(4, 4) * s
	var rect := Rect2(_center - half, half * 2.0)
	var sb := UITheme.box(UITheme.WOOD, int(30 * s), UITheme.WOOD_DARK, maxi(int(4 * s), 2), int(20 * s))
	draw_style_box(sb, rect)
	# Wood grain: gentle wavy strokes clipped inside the panel
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var inset := rect.grow(-14 * s)
	var y := inset.position.y
	while y < inset.end.y:
		y += rng.randf_range(9.0, 26.0) * s
		if y >= inset.end.y:
			break
		var pts := PackedVector2Array()
		var phase := rng.randf() * TAU
		var amp := rng.randf_range(1.0, 3.5) * s
		for k in range(25):
			var x := inset.position.x + inset.size.x * k / 24.0
			pts.append(Vector2(x, y + sin(phase + k * 0.45) * amp))
		draw_polyline(pts, Color(0.45, 0.28, 0.1, rng.randf_range(0.05, 0.11)), maxf(1.2 * s, 1.0), true)

func _draw_middle_band() -> void:
	## Highlights the row the winner must seal.
	var s := _scale
	var a := get_node_pos(3) - Vector2(50, 40) * s
	var b := get_node_pos(5) + Vector2(50, 40) * s
	var sb := UITheme.box(Color(1, 0.93, 0.7, 0.32), int(40 * s), Color(UITheme.ACCENT, 0.55), maxi(int(2 * s), 1))
	draw_style_box(sb, Rect2(a, b - a))

func _draw_lines() -> void:
	var w := maxf(7.0 * _scale, 2.0)
	for e in EDGES:
		var p0 := get_node_pos(e.x)
		var p1 := get_node_pos(e.y)
		draw_line(p0 + Vector2(0, 2) * _scale, p1 + Vector2(0, 2) * _scale, Color(1, 1, 1, 0.25), w, true)
		draw_line(p0, p1, UITheme.WOOD_LINE, w, true)

func _draw_jars() -> void:
	var s := _scale
	for i in BoardRules.GOALS:
		var p := get_node_pos(i)
		var r := JAR_R * s
		draw_circle(p + Vector2(0, 4) * s, r + 3 * s, Color(0.2, 0.12, 0.05, 0.25), true)
		draw_circle(p, r, UITheme.JAR_RIM, true)
		draw_circle(p, r * 0.78, UITheme.JAR_INNER.lightened(0.12), true)
		draw_texture_rect(_tex_jar, Rect2(p - Vector2(r, r) * 0.78, Vector2(r, r) * 1.56), false)
		draw_arc(p, r - 1.5 * s, 0, TAU, 64, UITheme.JAR_RIM.lightened(0.3), 3.0 * s, true)
		draw_arc(p, r * 0.78, 0, TAU, 64, Color(0, 0, 0, 0.35), 2.0 * s, true)

func _draw_dots() -> void:
	var s := _scale
	for i in range(3, 9):
		var p := get_node_pos(i)
		draw_circle(p, DOT_R * s, UITheme.WOOD_LINE, true)
		draw_circle(p - Vector2(2.5, 2.5) * s, 3.0 * s, Color(1, 1, 1, 0.35), true)

func _draw_last_move() -> void:
	if _last_from < 0 or _last_player < 0 or not _anim.is_empty():
		return
	var s := _scale
	var c := Color(UITheme.PLAYER_COLORS[_last_player], 0.6)
	_draw_dashed_circle(get_node_pos(_last_from), (PIECE_R - 6) * s, c, 3.0 * s)

func _draw_dashed_circle(p: Vector2, r: float, c: Color, w: float) -> void:
	var segs := 14
	for k in range(segs):
		var a0 := TAU * k / segs
		draw_arc(p, r, a0, a0 + TAU / segs * 0.55, 6, c, w, true)

func _draw_targets() -> void:
	var s := _scale
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	for t in _targets:
		var p := get_node_pos(t)
		var hovered: bool = t == _hover
		var r := (15.0 + 4.0 * pulse + (5.0 if hovered else 0.0)) * s
		draw_texture_rect(_tex_glow, Rect2(p - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false)
		draw_circle(p, r, Color(UITheme.ACCENT, 0.85 if hovered else 0.6), true)
		draw_arc(p, r, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.5 * s, true)

func _draw_pieces() -> void:
	var s := _scale
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	for i in range(_board.size()):
		var owner_id: int = _board[i]
		if owner_id < 0:
			continue
		var p: Vector2 = _anim.get(i, get_node_pos(i))
		var lifted := i == _selected or _anim.has(i)
		var lift := Vector2(0, -6) * s if i == _selected else Vector2.ZERO
		var r := PIECE_R * s
		# Soft shadow (larger when lifted)
		var sh := Vector2(0, 9 if lifted else 4) * s
		draw_circle(p + sh, r + 2 * s, Color(0.15, 0.08, 0.02, 0.16), true)
		draw_circle(p + sh * 0.6, r, Color(0.15, 0.08, 0.02, 0.2), true)
		p += lift
		if _winner >= 0 and owner_id == _winner:
			var gr := r * (1.9 + 0.25 * pulse)
			draw_texture_rect(_tex_glow, Rect2(p - Vector2(gr, gr), Vector2(gr, gr) * 2), false)
		# Body: dark rim + main color offset up-left = bevel
		var base := UITheme.PLAYER_COLORS[owner_id]
		var dark := UITheme.PLAYER_DARK[owner_id]
		draw_circle(p, r, dark, true)
		draw_circle(p - Vector2(1.2, 1.8) * s, r - 2.5 * s, base, true)
		draw_arc(p, r * 0.62, 0, TAU, 48, Color(dark, 0.35), 2.0 * s, true)
		var hr := r * 0.75
		draw_texture_rect(_tex_highlight, Rect2(p + Vector2(-r * 0.62, -r * 0.7) - Vector2(hr, hr) * 0.5, Vector2(hr, hr)), false)
		# Pieces trapped in a jar are dimmed
		if BoardRules.GOALS.has(i) and not _anim.has(i):
			draw_circle(p, r, Color(0.1, 0.06, 0.02, 0.28), true)
		# Rings: selected / hover / winner
		if i == _selected:
			draw_arc(p, r + 6 * s, 0, TAU, 48, UITheme.ACCENT, (3.0 + pulse * 1.5) * s, true)
		elif i == _hover and _clickable.has(i):
			draw_arc(p, r + 5 * s, 0, TAU, 48, Color(1, 1, 1, 0.85), 3.0 * s, true)
		if _winner >= 0 and owner_id == _winner:
			draw_arc(p, r + 6 * s, 0, TAU, 48, UITheme.ACCENT, 3.0 * s, true)
