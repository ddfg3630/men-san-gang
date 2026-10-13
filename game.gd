extends Control

## Core game controller for 悶三缸.
## Uses BoardRules for all rule logic. Builds the UI, manages state, input, AI, and effects.

# ── State machine ──
enum Phase { PICK_SIDE, PICK_DIFFICULTY, PLAYING, ANIMATING, FORCE_YIELD, GAME_OVER }

var _board: Array = []
var _current_player: int = 0
var _phase: int = Phase.PLAYING
var _selected: int = -1
var _yield_for: int = -1
var _is_yield_move: bool = false
var _last_move: Array = [[], []]
var _game_id: int = 0  # bumps on reset so stale timers can't touch a new game

var _ai: RefCounted = null

const AI_DELAY := 0.45
const RESULT_DELAY := 1.6
const LANDSCAPE_RATIO := 1.15

# ── UI ──
var _bg: Control
var _layout: BoxContainer
var _side: VBoxContainer
var _board_view: BoardView
var _fx: FxLayer
var _sfx: Sfx
var _cards: Array[PlayerCard] = []
var _mode_label: Label
var _status_panel: PanelContainer
var _status_label: Label
var _picker_panel: PanelContainer
var _picker_title: Label
var _picker_buttons: HBoxContainer
var _sound_btn: Button
var _win_modal: Modal
var _win_title: Label
var _win_sub: Label
var _rules: Modal

# ══════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════

func _ready() -> void:
	theme = UITheme.get_theme()
	_build_ui()
	resized.connect(_update_orientation)
	_update_orientation()
	_reset_game()

func _exit_tree() -> void:
	_board_view.kill_animation()
	_game_id += 1

func _reset_game() -> void:
	_game_id += 1
	_board = BoardRules.make_board()
	_current_player = 0
	_selected = -1
	_yield_for = -1
	_is_yield_move = false
	_last_move = [[], []]
	_board_view.kill_animation()
	_board_view.set_winner(-1)
	_board_view.set_last_move(-1, -1, -1)
	_fx.clear()

	if GameConfig.vs_ai:
		_ai = preload("res://ai_player.gd").new()
		if GameConfig.ai_side < 0:
			_phase = Phase.PICK_SIDE
			_show_picker("選擇你的陣營", [["藍方（先手）", UITheme.PLAYER_COLORS[0]], ["紅方（後手）", UITheme.PLAYER_COLORS[1]]], _on_side_picked)
		elif GameConfig.ai_difficulty < 0:
			_phase = Phase.PICK_DIFFICULTY
			_show_difficulty_picker()
		else:
			_start_after_config()
			return
	else:
		_phase = Phase.PLAYING
		_hide_picker()
	_refresh_view()

func _start_after_config() -> void:
	_ai.max_depth = GameConfig.get_ai_depth()
	_ai.eval_noise = GameConfig.get_ai_noise()
	_phase = Phase.PLAYING
	_hide_picker()
	_refresh_view()
	if _is_ai_turn():
		_schedule(_do_ai_turn, AI_DELAY)

# ══════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_bg = preload("res://paper_background.gd").new()
	add_child(_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	# Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	top.add_child(_ghost_button("‹ 主選單", _on_menu_pressed))
	_mode_label = UITheme.make_label("", 24, "TitleLabel")
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_label.add_theme_font_override("font", UITheme.TITLE_FONT)
	top.add_child(_mode_label)
	top.add_child(_ghost_button("重新開始", _on_restart_pressed))
	top.add_child(_ghost_button("規則", func() -> void: _rules.open()))
	_sound_btn = _ghost_button("", _on_sound_toggled)
	top.add_child(_sound_btn)
	_update_sound_button()

	# Board + side panel (orientation switches with the window shape)
	_layout = BoxContainer.new()
	_layout.add_theme_constant_override("separation", 18)
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_layout)

	_board_view = BoardView.new()
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.custom_minimum_size = Vector2(320, 260)
	_board_view.node_clicked.connect(_on_node_clicked)
	_board_view.animation_finished.connect(_on_animation_finished)
	_layout.add_child(_board_view)

	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_side)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	_side.add_child(cards)
	for p in [0, 1]:
		var card := PlayerCard.new(p)
		cards.add_child(card)
		_cards.append(card)

	_status_panel = PanelContainer.new()
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.add_child(_status_panel)
	_status_label = UITheme.make_label("", 22)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 64)
	_status_panel.add_child(_status_label)

	_picker_panel = PanelContainer.new()
	_side.add_child(_picker_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	_picker_panel.add_child(pv)
	_picker_title = UITheme.make_label("", 24, "TitleLabel")
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_picker_title)
	_picker_buttons = HBoxContainer.new()
	_picker_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_picker_buttons.add_theme_constant_override("separation", 12)
	pv.add_child(_picker_buttons)

	_fx = FxLayer.new()
	add_child(_fx)

	_sfx = Sfx.new()
	add_child(_sfx)

	# Result dialog
	_win_modal = Modal.new()
	_win_modal.dismissible = false
	add_child(_win_modal)
	_win_title = UITheme.make_label("", 52)
	_win_title.add_theme_font_override("font", UITheme.TITLE_FONT)
	_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_modal.content.add_child(_win_title)
	_win_sub = UITheme.make_label("", 19, "MutedLabel")
	_win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_modal.content.add_child(_win_sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_win_modal.content.add_child(spacer)
	var wb := HBoxContainer.new()
	wb.add_theme_constant_override("separation", 14)
	wb.alignment = BoxContainer.ALIGNMENT_CENTER
	_win_modal.content.add_child(wb)
	for spec in [["再來一局", _on_restart_pressed], ["回主選單", _on_menu_pressed]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(170, 54)
		b.pressed.connect(spec[1])
		wb.add_child(b)

	_rules = Modal.make_rules()
	add_child(_rules)

func _ghost_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "GhostButton"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _update_orientation() -> void:
	var landscape := size.x > size.y * LANDSCAPE_RATIO
	_layout.vertical = not landscape
	_side.custom_minimum_size.x = clampf(size.x * 0.3, 420.0, 560.0) if landscape else 0.0
	_side.size_flags_vertical = Control.SIZE_SHRINK_CENTER if landscape else Control.SIZE_FILL
	_side.size_flags_horizontal = Control.SIZE_FILL

func _show_picker(title: String, options: Array, cb: Callable) -> void:
	_picker_title.text = title
	for c in _picker_buttons.get_children():
		c.queue_free()
	for i in range(options.size()):
		var b := Button.new()
		b.text = options[i][0]
		b.custom_minimum_size = Vector2(118, 56)
		UITheme.apply_button(b, options[i][1])
		b.pressed.connect(func() -> void:
			_sfx.play("select")
			cb.call(i))
		_picker_buttons.add_child(b)
	_picker_panel.visible = true
	_status_panel.visible = false

func _show_difficulty_picker() -> void:
	var opts: Array = []
	for i in range(3):
		opts.append([UITheme.DIFFICULTY_NAMES[i], UITheme.DIFFICULTY_COLORS[i]])
	_show_picker("選擇難度", opts, _on_difficulty_picked)

func _hide_picker() -> void:
	_picker_panel.visible = false
	_status_panel.visible = true

# ══════════════════════════════════════════════════════════════
#  VIEW SYNC
# ══════════════════════════════════════════════════════════════

func _refresh_view() -> void:
	_board_view.set_board(_board)
	if _selected >= 0:
		_board_view.set_selection(_selected, _targets_for(_selected))
	else:
		_board_view.clear_selection()
	_board_view.set_clickable(_clickable_nodes())
	_status_label.text = _status_text()
	var urgent := _phase == Phase.FORCE_YIELD
	_status_panel.add_theme_stylebox_override("panel", UITheme.box(
		UITheme.PAPER.lerp(UITheme.ACCENT, 0.15 if urgent else 0.0), 18,
		UITheme.ACCENT if urgent else UITheme.PAPER_BORDER, 3 if urgent else 2, 10, Vector2(22, 12)))
	_update_mode_label()
	_update_cards()

func _update_mode_label() -> void:
	if not GameConfig.vs_ai:
		_mode_label.text = "雙人對戰"
	elif GameConfig.ai_difficulty >= 0:
		_mode_label.text = "人機對戰 · %s" % UITheme.DIFFICULTY_NAMES[GameConfig.ai_difficulty]
	else:
		_mode_label.text = "人機對戰"

func _update_cards() -> void:
	var picking := _phase == Phase.PICK_SIDE or _phase == Phase.PICK_DIFFICULTY
	for p in [0, 1]:
		var role := ""
		if GameConfig.vs_ai and GameConfig.ai_side >= 0:
			role = "（電腦）" if p == GameConfig.ai_side else "（你）"
		var trapped := [0, 0]
		for g in BoardRules.GOALS:
			if _board[g] >= 0:
				trapped[_board[g]] += 1
		_cards[p].set_info(UITheme.PLAYER_NAMES[p] + role, "困住對手 %d/3 · 被困 %d/3" % [trapped[1 - p], trapped[p]])
		var active: bool = not picking and _current_player == p
		if _phase == Phase.GAME_OVER:
			active = BoardRules.check_win(_board, p)
		_cards[p].set_active(active)

func _status_text() -> String:
	match _phase:
		Phase.PLAYING:
			if _is_ai_turn():
				return "電腦思考中…"
			if _selected >= 0:
				return "點擊金色亮點移動棋子"
			if GameConfig.vs_ai:
				return "輪到你了，選一顆棋子"
			return "%s：選一顆棋子" % _player_name(_current_player)
		Phase.FORCE_YIELD:
			if _is_ai_turn():
				return "%s被堵死，電腦讓路中…" % _player_name(_yield_for)
			if _selected >= 0:
				return "選擇要讓到哪個位置"
			return "%s被堵死了！%s必須讓出一步" % [_player_name(_yield_for), _player_name(_current_player)]
		Phase.ANIMATING:
			return "…"
		Phase.GAME_OVER:
			return "對局結束"
	return ""

func _player_name(p: int) -> String:
	if GameConfig.vs_ai and GameConfig.ai_side >= 0:
		return "電腦" if p == GameConfig.ai_side else "你"
	return UITheme.PLAYER_NAMES[p]

func _targets_for(node: int) -> Array:
	if _phase == Phase.FORCE_YIELD:
		return _get_yield_targets(node)
	var forbidden := BoardRules.get_forbidden_reverse(_last_move[_current_player])
	return BoardRules.get_moves_filtered(_board, node, forbidden)

func _clickable_nodes() -> Array:
	if (_phase != Phase.PLAYING and _phase != Phase.FORCE_YIELD) or _is_ai_turn():
		return []
	var result: Array = []
	for i in range(BoardRules.NODE_COUNT):
		if _board[i] == _current_player and not _targets_for(i).is_empty():
			result.append(i)
	if _selected >= 0:
		result.append_array(_targets_for(_selected))
	return result

func _board_global(node: int) -> Vector2:
	## Board node position in FxLayer space.
	return _board_view.get_global_transform() * _board_view.get_node_pos(node) - _fx.global_position

# ══════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════

func _on_node_clicked(clicked: int) -> void:
	if _phase != Phase.PLAYING and _phase != Phase.FORCE_YIELD:
		return
	if _is_ai_turn():
		return
	if clicked < 0:
		if _selected >= 0:
			_deselect()
		return
	if _board[clicked] == _current_player:
		if clicked == _selected:
			_deselect()
		else:
			_try_select(clicked)
	elif _selected >= 0:
		_try_move(clicked)

func _on_side_picked(side: int) -> void:
	GameConfig.ai_side = 1 - side  # player picks blue(0) → AI is red(1)
	if GameConfig.ai_difficulty < 0:
		_phase = Phase.PICK_DIFFICULTY
		_show_difficulty_picker()
		_refresh_view()
	else:
		_start_after_config()

func _on_difficulty_picked(diff: int) -> void:
	GameConfig.ai_difficulty = diff
	_start_after_config()

# ══════════════════════════════════════════════════════════════
#  PIECE SELECTION & MOVEMENT
# ══════════════════════════════════════════════════════════════

func _try_select(node: int) -> void:
	if node < 0 or _board[node] != _current_player:
		return
	if _targets_for(node).is_empty():
		return
	_selected = node
	_sfx.play("select")
	_refresh_view()

func _deselect() -> void:
	_selected = -1
	_refresh_view()

func _try_move(target: int) -> void:
	if not _targets_for(_selected).has(target):
		return
	_execute_move(_selected, target, _phase == Phase.FORCE_YIELD)

# ══════════════════════════════════════════════════════════════
#  MOVE EXECUTION
# ══════════════════════════════════════════════════════════════

func _execute_move(from: int, to: int, is_yield: bool) -> void:
	_phase = Phase.ANIMATING
	_selected = -1
	_is_yield_move = is_yield
	_refresh_view()
	_board_view.animate_piece(from, to)

func _on_animation_finished(from: int, to: int) -> void:
	if not is_inside_tree():
		return
	_apply_move(from, to)

func _apply_move(from: int, to: int) -> void:
	## Single entry point for board state change.
	var mover := _current_player
	_last_move[mover] = [from, to]
	_board = BoardRules.apply_move(_board, from, to)
	_board_view.set_last_move(from, to, mover)
	_play_move_fx(from, to, mover)

	if _is_yield_move:
		_finish_yield()
	else:
		_finish_normal_move()

func _play_move_fx(from: int, to: int, mover: int) -> void:
	var pos := _board_global(to)
	var c := UITheme.PLAYER_COLORS[mover]
	var s := _board_view.board_scale()
	_fx.ring(pos, c, 26 * s, 62 * s, 0.5, 5 * s)
	_fx.burst(pos, UITheme.WOOD_DARK, 10, 200 * s, 3.5 * s)
	if BoardRules.GOALS.has(to):
		_sfx.play("trap")
		_fx.ring(pos, UITheme.JAR_INNER, 50 * s, 20 * s, 0.4, 6 * s)
		_fx.float_text(pos + Vector2(0, -50 * s), "入缸", c, int(34 * s))
		_board_view.shake(7.0)
	elif BoardRules.GOALS.has(from):
		_sfx.play("place")
		_fx.float_text(pos + Vector2(0, -50 * s), "脫困", c, int(28 * s))
	else:
		_sfx.play("place")

func _finish_yield() -> void:
	var unblocked := _yield_for
	_yield_for = -1
	_is_yield_move = false
	_current_player = unblocked

	# Board changed due to yield — clear the unblocked player's anti-repeat
	# restriction since the back-and-forth context is broken.
	_last_move[unblocked] = []

	# Safety: also lift anti-repeat for the yielder if needed
	var yielder := 1 - unblocked
	if BoardRules.should_lift_antirepeat(_board, yielder, _last_move[yielder]):
		_last_move[yielder] = []

	_phase = Phase.PLAYING
	_on_turn_changed()

func _finish_normal_move() -> void:
	# Only the player who just moved can win, so the winner makes the final move.
	if BoardRules.check_win(_board, _current_player):
		_show_win(_current_player)
		return

	_current_player = 1 - _current_player

	# Auto-lift anti-repeat if it's the only thing blocking
	if BoardRules.should_lift_antirepeat(_board, _current_player, _last_move[_current_player]):
		_last_move[_current_player] = []
		_fx.float_text(_board_global(4) + Vector2(0, 40 * _board_view.board_scale()), "禁回頭解除", UITheme.INK_SOFT, int(24 * _board_view.board_scale()))

	if BoardRules.is_blocked(_board, _current_player):
		if BoardRules.is_blocked(_board, 1 - _current_player):
			_show_draw()
			return
		_yield_for = _current_player
		_current_player = 1 - _current_player
		_phase = Phase.FORCE_YIELD
		_sfx.play("yield")
		_fx.float_text(_board_global(4) + Vector2(0, -20 * _board_view.board_scale()), "讓路！", UITheme.ACCENT.darkened(0.2), int(44 * _board_view.board_scale()))
		_board_view.shake(4.0)
		_on_turn_changed()
		return

	_phase = Phase.PLAYING
	_on_turn_changed()

func _on_turn_changed() -> void:
	_refresh_view()
	_cards[_current_player].pulse()
	_bg.set_tint(UITheme.PLAYER_COLORS[_current_player])
	if _is_ai_turn():
		if _phase == Phase.FORCE_YIELD:
			_schedule(_do_ai_yield, AI_DELAY)
		else:
			_schedule(_do_ai_turn, AI_DELAY)

# ══════════════════════════════════════════════════════════════
#  YIELD HELPERS
# ══════════════════════════════════════════════════════════════

func _get_yield_targets(node: int) -> Array:
	var raw := BoardRules.get_moves(_board, node)
	var result: Array = []
	for target in raw:
		var ti: int = target
		var sim := BoardRules.apply_move(_board, node, ti)
		if BoardRules.has_any_move_raw(sim, _yield_for):
			result.append(ti)
	return result

# ══════════════════════════════════════════════════════════════
#  AI
# ══════════════════════════════════════════════════════════════

func _is_ai_turn() -> bool:
	return GameConfig.vs_ai and GameConfig.ai_side >= 0 and _current_player == GameConfig.ai_side

func _schedule(cb: Callable, delay: float) -> void:
	## Runs cb after delay, unless the game was reset or left in the meantime.
	var id := _game_id
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if id == _game_id and is_inside_tree():
			cb.call()
	, CONNECT_ONE_SHOT)

func _do_ai_turn() -> void:
	if _ai == null or _phase != Phase.PLAYING:
		return
	var forbidden := BoardRules.get_forbidden_reverse(_last_move[GameConfig.ai_side])
	var move: Array = _ai.get_best_move(_board.duplicate(), GameConfig.ai_side, forbidden)
	if move.size() == 2:
		_execute_move(move[0], move[1], false)

func _do_ai_yield() -> void:
	if _phase != Phase.FORCE_YIELD:
		return
	var yield_moves := BoardRules.get_yield_moves(_board, GameConfig.ai_side, _yield_for)
	if not yield_moves.is_empty():
		var mv: Array = yield_moves[0]
		_execute_move(mv[0], mv[1], true)

# ══════════════════════════════════════════════════════════════
#  END GAME
# ══════════════════════════════════════════════════════════════

func _show_win(winner: int) -> void:
	_phase = Phase.GAME_OVER
	_current_player = winner
	_board_view.set_winner(winner)
	_refresh_view()
	_bg.set_tint(UITheme.PLAYER_COLORS[winner], 0.1)
	_sfx.play("win")
	_fx.confetti([UITheme.PLAYER_COLORS[winner], UITheme.ACCENT, UITheme.PLAYER_COLORS[winner].lightened(0.4), UITheme.PAPER], 90)
	for g in BoardRules.GOALS:
		_fx.ring(_board_global(g), UITheme.PLAYER_COLORS[winner], 20, 90 * _board_view.board_scale(), 0.9, 6)
	var human_lost := GameConfig.vs_ai and winner == GameConfig.ai_side
	if GameConfig.vs_ai:
		_win_title.text = "電腦獲勝" if human_lost else "你贏了！"
	else:
		_win_title.text = "%s獲勝！" % UITheme.PLAYER_NAMES[winner]
	_win_title.add_theme_color_override("font_color", UITheme.PLAYER_COLORS[winner])
	_win_sub.text = "對手三子盡數入缸，無路可逃"
	_status_label.text = _win_title.text
	_schedule(_win_modal.open, RESULT_DELAY)

func _show_draw() -> void:
	_phase = Phase.GAME_OVER
	_refresh_view()
	_sfx.play("draw")
	_win_title.text = "平局"
	_win_title.add_theme_color_override("font_color", UITheme.INK)
	_win_sub.text = "雙方都無路可走"
	_status_label.text = "平局！雙方都無路可走"
	_schedule(_win_modal.open, RESULT_DELAY)

# ══════════════════════════════════════════════════════════════
#  UI CALLBACKS
# ══════════════════════════════════════════════════════════════

func _on_restart_pressed() -> void:
	## Restart with the same side and difficulty.
	_win_modal.visible = false
	_bg.set_tint(Color.WHITE, 0.0)
	_reset_game()

func _on_menu_pressed() -> void:
	_board_view.kill_animation()
	_game_id += 1
	get_tree().change_scene_to_file("res://main.tscn")

func _on_sound_toggled() -> void:
	GameConfig.sound_on = not GameConfig.sound_on
	_update_sound_button()
	_sfx.play("select")

func _update_sound_button() -> void:
	_sound_btn.text = "音效：開" if GameConfig.sound_on else "音效：關"
