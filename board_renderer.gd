extends Node2D
## Renders board visuals with responsive layout.
## All positions computed dynamically from viewport size.

# ── Visual constants (proportional, scaled at runtime) ──
const LINE_WIDTH := 4.0
const LINE_COLOR := Color(0.235, 0.235, 0.235)
const NODE_RADIUS_BASE := 8.0
const NODE_COLOR := Color(0.4, 0.38, 0.35)
const PIECE_RADIUS_BASE := 28.0
const HIGHLIGHT_RADIUS_BASE := 22.0
const CIRCLE_RADIUS_BASE := 38.0
const CLICK_TOLERANCE_BASE := 44.0
const ANIM_DURATION := 0.25
const HIGHLIGHT_COLOR := Color(1.0, 0.843, 0.0, 0.5)
const SELECTED_GLOW := Color(1.0, 1.0, 0.4, 0.6)

var _circle_fills: Array = [Color(0.478,0.702,0.878,0.35), Color(0.91,0.651,0.29,0.35), Color(0.42,0.749,0.42,0.35)]
var _circle_borders: Array = [Color(0.478,0.702,0.878,0.8), Color(0.91,0.651,0.29,0.8), Color(0.42,0.749,0.42,0.8)]
var _player_colors: Array = [Color(0.29,0.565,0.851), Color(0.851,0.29,0.29)]
var _player_borders: Array = [Color(0.173,0.373,0.541), Color(0.541,0.173,0.173)]
var _player_highlights: Array = [Color(0.55,0.73,0.92), Color(0.92,0.55,0.55)]

var _edge_pairs: Array = [0,3, 1,4, 2,5, 3,6, 4,7, 5,8, 3,4, 4,5, 6,7, 7,8]

# ── Layout computed values ──
var _node_positions: Array = []
var _scale_factor: float = 1.0
var _board_top: float = 0.0
var _ui_y1: float = 0.0  # status bar Y
var _ui_y2: float = 0.0  # turn bar Y
var _vp_center_x: float = 400.0

# ── State ──
var _board_state: Array = []
var _selected_node: int = -1
var _valid_moves: Array = []
var _anim_positions: Dictionary = {}
var _status_text: String = ""
var _turn_text: String = ""
var _current_tween: Tween = null
var _picker_mode: String = ""
var _picker_btn_rects: Array = []

signal animation_finished(from_node: int, to_node: int)

# ══════════════════════════════════════════
#  LAYOUT COMPUTATION
# ══════════════════════════════════════════

func _compute_layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_vp_center_x = vp.x / 2.0

	# Board occupies 70% of the narrower dimension for spacing
	var board_w: float = vp.x * 0.7
	_scale_factor = board_w / 480.0  # 480 = original spread (640-160)

	# Vertical layout: board in upper portion, UI bars below
	var total_h := vp.y
	var board_h := 340.0 * _scale_factor  # original board height (500-160)
	_board_top = total_h * 0.12  # start board at 12% from top

	var col_left := _vp_center_x - 240.0 * _scale_factor
	var col_mid := _vp_center_x
	var col_right := _vp_center_x + 240.0 * _scale_factor

	var circle_y := _board_top
	var row1_y := _board_top + 180.0 * _scale_factor
	var row2_y := _board_top + 340.0 * _scale_factor

	_node_positions = [
		Vector2(col_left, circle_y), Vector2(col_mid, circle_y), Vector2(col_right, circle_y),
		Vector2(col_left, row1_y), Vector2(col_mid, row1_y), Vector2(col_right, row1_y),
		Vector2(col_left, row2_y), Vector2(col_mid, row2_y), Vector2(col_right, row2_y),
	]

	# UI bars positioned in the lower portion
	var ui_start := row2_y + 80.0 * _scale_factor
	var ui_gap := 70.0 * _scale_factor
	_ui_y1 = minf(ui_start, total_h - ui_gap * 2 - 20)
	_ui_y2 = _ui_y1 + ui_gap

# Scaled accessors
func _piece_r() -> float: return PIECE_RADIUS_BASE * _scale_factor
func _highlight_r() -> float: return HIGHLIGHT_RADIUS_BASE * _scale_factor
func _circle_r() -> float: return CIRCLE_RADIUS_BASE * _scale_factor
func _node_r() -> float: return NODE_RADIUS_BASE * _scale_factor
func _click_tol() -> float: return CLICK_TOLERANCE_BASE * _scale_factor

# ══════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════

func set_board(board: Array) -> void:
	_board_state = board.duplicate()
	queue_redraw()

func set_selection(node: int, valid_targets: Array) -> void:
	_selected_node = node
	_valid_moves = valid_targets
	queue_redraw()

func clear_selection() -> void:
	_selected_node = -1
	_valid_moves = []
	queue_redraw()

func set_status(status: String, turn: String) -> void:
	_status_text = status
	_turn_text = turn
	queue_redraw()

func set_picker_mode(mode: String) -> void:
	_picker_mode = mode
	_picker_btn_rects = []
	queue_redraw()

func animate_piece(from: int, to: int) -> void:
	kill_animation()
	var sp: Vector2 = get_node_pos(from)
	var ep: Vector2 = get_node_pos(to)
	_anim_positions[from] = sp
	queue_redraw()
	_current_tween = create_tween()
	_current_tween.tween_method(func(t: float) -> void:
		_anim_positions[from] = sp.lerp(ep, t)
		queue_redraw()
	, 0.0, 1.0, ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_current_tween.tween_callback(func() -> void:
		_anim_positions.erase(from)
		_current_tween = null
		animation_finished.emit(from, to)
	)

func kill_animation() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
	_anim_positions.clear()

func get_node_pos(idx: int) -> Vector2:
	if idx < 0 or idx >= _node_positions.size():
		return Vector2.ZERO
	return _node_positions[idx] as Vector2

func hit_test(click_pos: Vector2) -> int:
	var best := -1
	var best_dist := _click_tol()
	for i in range(_node_positions.size()):
		var p: Vector2 = _node_positions[i] as Vector2
		var d := click_pos.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = i
	return best

func picker_hit_test(click_pos: Vector2) -> int:
	for i in range(_picker_btn_rects.size()):
		var r: Rect2 = _picker_btn_rects[i] as Rect2
		if r.has_point(click_pos):
			return i
	return -1

# ══════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════

func _ready() -> void:
	_compute_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_compute_layout()
	queue_redraw()

# ══════════════════════════════════════════
#  DRAWING
# ══════════════════════════════════════════

func _draw() -> void:
	_draw_board_lines()
	_draw_goal_circles()
	_draw_node_dots()
	_draw_highlights()
	_draw_pieces()
	_draw_ui_bars()

func _draw_board_lines() -> void:
	var lw := maxf(LINE_WIDTH * _scale_factor * 0.7, 2.0)
	var i := 0
	while i < _edge_pairs.size():
		var a: int = _edge_pairs[i]
		var b: int = _edge_pairs[i + 1]
		draw_line(get_node_pos(a), get_node_pos(b), LINE_COLOR, lw, true)
		i += 2

func _draw_goal_circles() -> void:
	var cr := _circle_r()
	for i in range(3):
		var p: Vector2 = get_node_pos(i)
		var fc: Color = _circle_fills[i]
		var bc: Color = _circle_borders[i]
		draw_circle(p, cr, fc)
		draw_arc(p, cr, 0, TAU, 48, bc, 2.5, true)
		draw_arc(p, cr - 6 * _scale_factor, 0, TAU, 36, Color(bc.r, bc.g, bc.b, 0.3), 1.0, true)

func _draw_node_dots() -> void:
	var nr := _node_r()
	for i in range(3, 9):
		var p: Vector2 = get_node_pos(i)
		draw_circle(p, nr, NODE_COLOR)
		draw_circle(p + Vector2(-2, -2) * _scale_factor, 3.0 * _scale_factor, Color(1, 1, 1, 0.3))

func _draw_highlights() -> void:
	var hr := _highlight_r()
	var pr := _piece_r()
	for idx in _valid_moves:
		var ni: int = idx
		var p: Vector2 = get_node_pos(ni)
		draw_circle(p, hr, HIGHLIGHT_COLOR)
		draw_arc(p, hr, 0, TAU, 32, Color(1.0, 0.843, 0.0, 0.8), 2.0, true)
	if _selected_node >= 0:
		draw_circle(get_node_pos(_selected_node), pr + 6 * _scale_factor, SELECTED_GLOW)

func _draw_pieces() -> void:
	var pr := _piece_r()
	for i in range(_board_state.size()):
		var oid: int = _board_state[i]
		if oid < 0 or oid > 1:
			continue
		var p: Vector2
		if _anim_positions.has(i):
			p = _anim_positions[i] as Vector2
		else:
			p = get_node_pos(i)
		var mc: Color = _player_colors[oid]
		var bc: Color = _player_borders[oid]
		var hc: Color = _player_highlights[oid]
		draw_circle(p + Vector2(2, 3) * _scale_factor, pr, Color(0, 0, 0, 0.15))
		draw_circle(p, pr, mc)
		draw_arc(p, pr, 0, TAU, 48, bc, 2.5, true)
		draw_circle(p + Vector2(-7, -7) * _scale_factor, 10.0 * _scale_factor, hc)
		draw_circle(p + Vector2(-5, -5) * _scale_factor, 5.0 * _scale_factor, Color(1, 1, 1, 0.35))

# ── UI bars ──

func _draw_ui_bars() -> void:
	var fs1 := int(28 * _scale_factor)
	var fs2 := int(24 * _scale_factor)
	fs1 = clampi(fs1, 18, 42)
	fs2 = clampi(fs2, 16, 36)

	if _picker_mode == "side":
		DrawUtils.draw_text_bar(self, Vector2(_vp_center_x, _ui_y1), "請選擇你的陣營", fs1)
		_picker_btn_rects = _draw_two_buttons(_ui_y2,
			"藍 方", Color(0.29,0.565,0.851,0.8), Color(0.173,0.373,0.541,0.8),
			"紅 方", Color(0.851,0.29,0.29,0.8), Color(0.541,0.173,0.173,0.8))
		return

	if _picker_mode == "difficulty":
		DrawUtils.draw_text_bar(self, Vector2(_vp_center_x, _ui_y1), "選擇難度", fs1)
		_picker_btn_rects = _draw_three_buttons(_ui_y2)
		return

	if _status_text != "":
		DrawUtils.draw_text_bar(self, Vector2(_vp_center_x, _ui_y1), _status_text, fs1)
	if _turn_text != "":
		DrawUtils.draw_text_bar(self, Vector2(_vp_center_x, _ui_y2), _turn_text, fs2)

func _draw_two_buttons(y: float, t1: String, c1: Color, b1: Color, t2: String, c2: Color, b2: Color) -> Array:
	var w := 140.0 * _scale_factor
	var h := 50.0 * _scale_factor
	var gap := 30.0 * _scale_factor
	var fs := clampi(int(26 * _scale_factor), 18, 36)
	var r1 := Rect2(_vp_center_x - w - gap / 2, y - h / 2, w, h)
	var r2 := Rect2(_vp_center_x + gap / 2, y - h / 2, w, h)
	DrawUtils.draw_color_button(self, r1, t1, fs, c1, b1)
	DrawUtils.draw_color_button(self, r2, t2, fs, c2, b2)
	return [r1, r2]

func _draw_three_buttons(y: float) -> Array:
	var w := 120.0 * _scale_factor
	var h := 50.0 * _scale_factor
	var gap := 20.0 * _scale_factor
	var fs := clampi(int(24 * _scale_factor), 16, 32)
	var total := w * 3 + gap * 2
	var x0 := _vp_center_x - total / 2
	var r0 := Rect2(x0, y - h / 2, w, h)
	var r1 := Rect2(x0 + w + gap, y - h / 2, w, h)
	var r2 := Rect2(x0 + (w + gap) * 2, y - h / 2, w, h)
	DrawUtils.draw_color_button(self, r0, "簡 單", fs, Color(0.4, 0.7, 0.4, 0.8), Color(0.25, 0.5, 0.25, 0.8))
	DrawUtils.draw_color_button(self, r1, "普 通", fs, Color(0.85, 0.65, 0.25, 0.8), Color(0.6, 0.45, 0.15, 0.8))
	DrawUtils.draw_color_button(self, r2, "困 難", fs, Color(0.8, 0.3, 0.3, 0.8), Color(0.55, 0.18, 0.18, 0.8))
	return [r0, r1, r2]
