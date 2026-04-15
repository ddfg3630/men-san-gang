extends Node
## Self-play stress test for 悶三缸.
## Uses BoardRules for all logic — same rules as the real game.

const NUM_GAMES := 500
const MAX_TURNS := 300

var _wins := [0, 0]
var _draws := 0
var _errors: Array = []
var _total_turns := 0
var _yield_count := 0
var _antirepeat_lifts := 0
var _max_turns_hit := 0

func _ready() -> void:
	print("═══════════════════════════════════════════")
	print("  悶三缸 Self-Play Stress Test")
	print("  Games: %d | Max turns/game: %d" % [NUM_GAMES, MAX_TURNS])
	print("═══════════════════════════════════════════")

	for i in range(NUM_GAMES):
		_run_game(i)

	_print_report()
	get_tree().quit()

func _run_game(game_id: int) -> void:
	var board := BoardRules.make_board()
	var current := 0
	var last_move: Array = [[], []]
	var turn := 0

	while turn < MAX_TURNS:
		turn += 1

		var err := BoardRules.validate_board(board)
		if err != "":
			_errors.append("Game %d Turn %d: %s" % [game_id, turn, err])
			return

		for p in [0, 1]:
			if BoardRules.check_win(board, p):
				_wins[p] += 1
				_total_turns += turn
				return

		# Auto-lift anti-repeat if needed
		if BoardRules.should_lift_antirepeat(board, current, last_move[current]):
			last_move[current] = []
			_antirepeat_lifts += 1

		var forbidden := BoardRules.get_forbidden_reverse(last_move[current])
		var all_moves := BoardRules.get_all_moves(board, current, forbidden)

		if all_moves.is_empty():
			# Truly blocked — need yield
			var other := 1 - current
			var yield_moves := BoardRules.get_yield_moves(board, other, current)
			if yield_moves.is_empty():
				if not BoardRules.has_any_move_raw(board, other):
					_draws += 1
					_total_turns += turn
					return
				_errors.append("Game %d Turn %d: Player %d blocked, no valid yield" % [game_id, turn, current])
				return

			_yield_count += 1
			var ym: Array = yield_moves[randi() % yield_moves.size()]
			last_move[other] = [ym[0], ym[1]]
			board = BoardRules.apply_move(board, ym[0], ym[1])

			if not BoardRules.has_any_move_raw(board, current):
				_errors.append("Game %d Turn %d: Yield [%d→%d] didn't unblock player %d" % [game_id, turn, ym[0], ym[1], current])
				return
			continue

		# Random move
		var mv: Array = all_moves[randi() % all_moves.size()]
		# Verify anti-repeat
		if forbidden.size() == 2 and mv[0] == forbidden[0] and mv[1] == forbidden[1]:
			_errors.append("Game %d Turn %d: Anti-repeat violation [%d→%d]" % [game_id, turn, mv[0], mv[1]])
			return

		last_move[current] = [mv[0], mv[1]]
		board = BoardRules.apply_move(board, mv[0], mv[1])
		current = 1 - current

	_max_turns_hit += 1
	_total_turns += MAX_TURNS

func _print_report() -> void:
	print("")
	print("───────────── RESULTS ─────────────")
	print("  Games played:      %d" % NUM_GAMES)
	print("  Blue wins:         %d (%.1f%%)" % [_wins[0], 100.0 * _wins[0] / NUM_GAMES])
	print("  Red wins:          %d (%.1f%%)" % [_wins[1], 100.0 * _wins[1] / NUM_GAMES])
	print("  Draws:             %d" % _draws)
	print("  Max turns reached: %d" % _max_turns_hit)
	print("  Avg turns/game:    %.1f" % (float(_total_turns) / NUM_GAMES))
	print("  Yield events:      %d" % _yield_count)
	print("  Anti-repeat lifts: %d" % _antirepeat_lifts)
	print("  Errors found:      %d" % _errors.size())
	if _errors.is_empty():
		print("")
		print("  ALL GAMES PASSED")
	else:
		print("")
		print("  ERRORS:")
		for i in range(mini(_errors.size(), 20)):
			print("    - %s" % _errors[i])
		if _errors.size() > 20:
			print("    ... and %d more" % (_errors.size() - 20))
	print("═══════════════════════════════════════════")
