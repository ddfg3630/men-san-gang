extends Control

## Core game controller for 悶三缸.
## Uses BoardRules for all rule logic. Manages state, input, AI, and view sync.

# ── State machine ──
enum Phase { PICK_SIDE, PICK_DIFFICULTY, PLAYING, ANIMATING, FORCE_YIELD, GAME_OVER }

var _board: Array = []
var _current_player: int = 0
var _phase: int = Phase.PLAYING
var _selected: int = -1
var _yield_for: int = -1
var _is_yield_move: bool = false
var _last_move: Array = [[], []]
var _ai_timer: SceneTreeTimer = null

@onready var _renderer: Node2D = $BoardRenderer
@onready var _win_panel: PanelContainer = $WinPanel
@onready var _win_label: Label = $WinPanel/VBox/WinLabel

var _ai: RefCounted = null

const AI_DELAY := 0.4

# ══════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════

func _ready() -> void:
	_renderer.animation_finished.connect(_on_animation_finished)
	_reset_game()

func _exit_tree() -> void:
	_renderer.kill_animation()
	_ai_timer = null

func _reset_game() -> void:
	_board = BoardRules.make_board()
	_current_player = 0
	_selected = -1
	_yield_for = -1
	_last_move = [[], []]

	if GameConfig.vs_ai:
		_ai = preload("res://ai_player.gd").new()
		if GameConfig.ai_side < 0:
			_phase = Phase.PICK_SIDE
			_renderer.set_picker_mode("side")
		else:
			_start_after_config()
	else:
		_phase = Phase.PLAYING
		_renderer.set_picker_mode("")
	_refresh_view()

func _start_after_config() -> void:
	_ai.max_depth = GameConfig.get_ai_depth()
	_ai.eval_noise = GameConfig.get_ai_noise()
	_phase = Phase.PLAYING
	_renderer.set_picker_mode("")
	_refresh_view()
	if _is_ai_turn():
		_schedule_ai()

# ══════════════════════════════════════════════════════════════
#  VIEW SYNC
# ══════════════════════════════════════════════════════════════

func _refresh_view() -> void:
	_renderer.set_board(_board)
	if _selected >= 0 and _phase == Phase.FORCE_YIELD:
		_renderer.set_selection(_selected, _get_yield_targets(_selected))
	elif _selected >= 0:
		var forbidden := BoardRules.get_forbidden_reverse(_last_move[_current_player])
		_renderer.set_selection(_selected, BoardRules.get_moves_filtered(_board, _selected, forbidden))
	else:
		_renderer.clear_selection()
	_renderer.set_status(_status_text(), _turn_text())

func _status_text() -> String:
	match _phase:
		Phase.PICK_SIDE, Phase.PICK_DIFFICULTY:
			return ""  # renderer draws picker UI
		Phase.PLAYING:
			if _selected >= 0:
				return "請選擇移動目標（點擊黃色高亮處）"
			return "請選擇你的棋子"
		Phase.FORCE_YIELD:
			if _selected >= 0:
				return "選擇要讓到哪個位置"
			return "%s 被堵死了！%s 必須讓出一格" % [_player_name(_yield_for), _player_name(_current_player)]
		Phase.ANIMATING:
			return "移動中..."
		Phase.GAME_OVER:
			return "遊戲結束"
	return ""

func _turn_text() -> String:
	match _phase:
		Phase.PLAYING:
			return "%s 的回合" % _player_name(_current_player)
		Phase.FORCE_YIELD:
			return "%s 讓路中" % _player_name(_current_player)
	return ""

func _player_name(p: int) -> String:
	return "藍方" if p == 0 else "紅方"

# ══════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.GAME_OVER or _phase == Phase.ANIMATING:
		return
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var pos: Vector2 = mb.position

	# Picker phases
	if _phase == Phase.PICK_SIDE:
		var side: int = _renderer.picker_hit_test(pos)
		if side >= 0:
			_on_side_picked(side)
		return

	if _phase == Phase.PICK_DIFFICULTY:
		var diff: int = _renderer.picker_hit_test(pos)
		if diff >= 0:
			_on_difficulty_picked(diff)
		return

	if _is_ai_turn():
		return

	var clicked: int = _renderer.hit_test(pos)

	if _phase == Phase.PLAYING:
		if _selected < 0:
			_try_select(clicked)
		elif clicked < 0:
			_deselect()
		elif _board[clicked] == _current_player:
			_try_select(clicked)
		else:
			_try_move(clicked)
	elif _phase == Phase.FORCE_YIELD:
		_handle_yield_input(clicked)

func _on_side_picked(side: int) -> void:
	GameConfig.ai_side = 1 - side  # player picks blue(0) → AI is red(1)
	if GameConfig.ai_difficulty < 0:
		_phase = Phase.PICK_DIFFICULTY
		_renderer.set_picker_mode("difficulty")
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
	var forbidden := BoardRules.get_forbidden_reverse(_last_move[_current_player])
	# Check if this piece has any valid moves
	var moves: Array
	if _phase == Phase.FORCE_YIELD:
		moves = _get_yield_targets(node)
	else:
		moves = BoardRules.get_moves_filtered(_board, node, forbidden)
	if moves.is_empty():
		return
	_selected = node
	_refresh_view()

func _deselect() -> void:
	_selected = -1
	_refresh_view()

func _try_move(target: int) -> void:
	if target < 0:
		return
	var forbidden := BoardRules.get_forbidden_reverse(_last_move[_current_player])
	var moves: Array = BoardRules.get_moves_filtered(_board, _selected, forbidden)
	if not moves.has(target):
		return
	_execute_move(_selected, target, false)

func _handle_yield_input(node: int) -> void:
	if node < 0:
		if _selected >= 0:
			_deselect()
		return
	if _selected < 0:
		_try_select(node)
		return
	if node == _selected:
		_deselect()
		return
	if _board[node] == _current_player:
		_try_select(node)
		return
	var moves: Array = _get_yield_targets(_selected)
	if not moves.has(node):
		return
	_execute_move(_selected, node, true)

# ══════════════════════════════════════════════════════════════
#  MOVE EXECUTION
# ══════════════════════════════════════════════════════════════

func _execute_move(from: int, to: int, is_yield: bool) -> void:
	_phase = Phase.ANIMATING
	_selected = -1
	_is_yield_move = is_yield
	_renderer.clear_selection()
	_renderer.set_status("移動中...", "")
	_renderer.animate_piece(from, to)

func _on_animation_finished(from: int, to: int) -> void:
	if not is_inside_tree():
		return
	_apply_move(from, to)

func _apply_move(from: int, to: int) -> void:
	## Single entry point for board state change.
	_last_move[_current_player] = [from, to]
	_board = BoardRules.apply_move(_board, from, to)

	if _is_yield_move:
		_finish_yield()
	else:
		_finish_normal_move()

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
	_refresh_view()
	if _is_ai_turn():
		_schedule_ai()

func _finish_normal_move() -> void:
	for p in [0, 1]:
		if BoardRules.check_win(_board, p):
			_show_win(p)
			return

	_current_player = 1 - _current_player

	# Auto-lift anti-repeat if it's the only thing blocking
	if BoardRules.should_lift_antirepeat(_board, _current_player, _last_move[_current_player]):
		_last_move[_current_player] = []

	if BoardRules.is_blocked(_board, _current_player):
		if BoardRules.is_blocked(_board, 1 - _current_player):
			_show_draw()
			return
		_yield_for = _current_player
		_current_player = 1 - _current_player
		_phase = Phase.FORCE_YIELD
		_refresh_view()
		if _is_ai_turn():
			_schedule_ai_yield()
		return

	_phase = Phase.PLAYING
	_refresh_view()
	if _is_ai_turn():
		_schedule_ai()

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
	return GameConfig.vs_ai and _current_player == GameConfig.ai_side

func _schedule_ai() -> void:
	_ai_timer = get_tree().create_timer(AI_DELAY)
	_ai_timer.timeout.connect(_do_ai_turn, CONNECT_ONE_SHOT)

func _schedule_ai_yield() -> void:
	_ai_timer = get_tree().create_timer(AI_DELAY)
	_ai_timer.timeout.connect(_do_ai_yield, CONNECT_ONE_SHOT)

func _do_ai_turn() -> void:
	_ai_timer = null
	if not is_inside_tree() or _ai == null or _phase == Phase.GAME_OVER:
		return
	var forbidden := BoardRules.get_forbidden_reverse(_last_move[GameConfig.ai_side])
	var move: Array = _ai.get_best_move(_board.duplicate(), GameConfig.ai_side, forbidden)
	if move.size() == 2:
		_execute_move(move[0], move[1], false)

func _do_ai_yield() -> void:
	_ai_timer = null
	if not is_inside_tree() or _phase == Phase.GAME_OVER:
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
	_win_label.text = "%s 獲勝！" % _player_name(winner)
	# Show the final board state first, then popup after a delay
	_renderer.set_board(_board)
	_renderer.clear_selection()
	_renderer.set_status("%s 獲勝！" % _player_name(winner), "")
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func() -> void:
		if is_inside_tree():
			_win_panel.visible = true
	, CONNECT_ONE_SHOT)

func _show_draw() -> void:
	_phase = Phase.GAME_OVER
	_win_label.text = "平局！雙方都動不了"
	_renderer.set_board(_board)
	_renderer.clear_selection()
	_renderer.set_status("平局！雙方都動不了", "")
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func() -> void:
		if is_inside_tree():
			_win_panel.visible = true
	, CONNECT_ONE_SHOT)

# ══════════════════════════════════════════════════════════════
#  UI CALLBACKS
# ══════════════════════════════════════════════════════════════

func _on_restart_pressed() -> void:
	_renderer.kill_animation()
	_ai_timer = null
	_win_panel.visible = false
	GameConfig.ai_side = -1
	GameConfig.ai_difficulty = -1
	_reset_game()

func _on_menu_pressed() -> void:
	_renderer.kill_animation()
	_ai_timer = null
	get_tree().change_scene_to_file("res://main.tscn")

func _on_back_pressed() -> void:
	_on_menu_pressed()
