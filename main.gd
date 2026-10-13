extends Control
## Title screen: animated backdrop, a self-playing demo board, and mode buttons.

const DEMO_STEP := 1.3

var _demo: BoardView
var _demo_board: Array = []
var _demo_turn := 0
var _demo_last: Array = [[], []]
var _demo_moves := 0
var _rules: Modal
var _sfx: Sfx

func _ready() -> void:
	theme = UITheme.get_theme()
	add_child(preload("res://paper_background.gd").new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := UITheme.make_label("悶三缸", 104)
	title.add_theme_font_override("font", UITheme.TITLE_FONT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", UITheme.PAPER)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.1, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := UITheme.make_label("傳 統 棋 類 對 弈 遊 戲", 20, "MutedLabel")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	_demo = BoardView.new()
	_demo.interactive = false
	_demo.custom_minimum_size = Vector2(400, 312)
	_demo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_demo.animation_finished.connect(_on_demo_moved)
	vb.add_child(_demo)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.custom_minimum_size = Vector2(300, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(buttons)
	var pvp := _menu_button("雙人對戰", _on_pvp_button_pressed)
	buttons.add_child(pvp)
	buttons.add_child(_menu_button("人機對戰", _on_ai_button_pressed))
	var rules_btn := _menu_button("遊戲規則", func() -> void: _rules.open())
	rules_btn.theme_type_variation = "GhostButton"
	rules_btn.add_theme_font_size_override("font_size", 20)
	buttons.add_child(rules_btn)

	var footer := UITheme.make_label("把對手三子全困進缸裡就贏了", 16, "MutedLabel")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(footer)

	_rules = Modal.make_rules()
	add_child(_rules)
	_sfx = Sfx.new()
	add_child(_sfx)

	pvp.grab_focus.call_deferred()
	_demo_reset()
	_demo_schedule()

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 58)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func() -> void:
		_sfx.play("select")
		cb.call())
	return b

# ── Demo board: plays random legal moves forever ──

func _demo_reset() -> void:
	_demo_board = BoardRules.make_board()
	_demo_turn = 0
	_demo_last = [[], []]
	_demo_moves = 0
	_demo.set_board(_demo_board)
	_demo.set_last_move(-1, -1, -1)

func _demo_schedule() -> void:
	get_tree().create_timer(DEMO_STEP).timeout.connect(_demo_step, CONNECT_ONE_SHOT)

func _demo_step() -> void:
	if not is_inside_tree():
		return
	if _demo_moves > 40:
		_demo_reset()
		_demo_schedule()
		return
	if BoardRules.should_lift_antirepeat(_demo_board, _demo_turn, _demo_last[_demo_turn]):
		_demo_last[_demo_turn] = []
	var moves := BoardRules.get_all_moves(_demo_board, _demo_turn, BoardRules.get_forbidden_reverse(_demo_last[_demo_turn]))
	if moves.is_empty():
		_demo_reset()
		_demo_schedule()
		return
	var mv: Array = moves[randi() % moves.size()]
	_demo_last[_demo_turn] = mv
	_demo.animate_piece(mv[0], mv[1])

func _on_demo_moved(from: int, to: int) -> void:
	if not is_inside_tree():
		return
	_demo_board = BoardRules.apply_move(_demo_board, from, to)
	_demo.set_board(_demo_board)
	_demo.set_last_move(from, to, _demo_turn)
	_demo_turn = 1 - _demo_turn
	_demo_moves += 1
	_demo_schedule()

# ── Navigation ──

func _on_pvp_button_pressed() -> void:
	GameConfig.vs_ai = false
	get_tree().change_scene_to_file("res://game.tscn")

func _on_ai_button_pressed() -> void:
	GameConfig.vs_ai = true
	GameConfig.ai_side = -1
	GameConfig.ai_difficulty = -1
	get_tree().change_scene_to_file("res://game.tscn")
