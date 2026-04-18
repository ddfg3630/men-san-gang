extends Node
## Tests AI vs AI at different difficulty configs to measure strength differentiation.

const NUM_GAMES := 100
const MAX_TURNS := 300

var _ai_script = preload("res://ai_player.gd")

func _ready() -> void:
	print("═══════════════════════════════════════════════════════════════")
	print("  悶三缸 AI Difficulty Benchmark")
	print("  %d games per matchup | Max %d turns/game" % [NUM_GAMES, MAX_TURNS])
	print("  Format: Depth/Noise")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	# Configs: [depth, noise, label]
	var easy: Array = [2, 60, "Easy(2/60)"]
	var normal: Array = [4, 15, "Normal(4/15)"]
	var hard: Array = [6, 0, "Hard(6/0)"]

	print("── AI vs Random ──")
	var random: Array = [0, 0, "Random"]
	_run_matchup(easy, random)
	_run_matchup(normal, random)
	_run_matchup(hard, random)
	print("")

	print("── Same Difficulty (symmetry test) ──")
	_run_matchup(easy, easy)
	_run_matchup(normal, normal)
	print("")

	print("── Cross-Difficulty ──")
	_run_matchup(easy, normal)
	_run_matchup(easy, hard)
	_run_matchup(normal, hard)
	print("")

	# Reverse sides (red = stronger)
	print("── Reversed (stronger as Red) ──")
	_run_matchup(normal, easy)
	_run_matchup(hard, easy)
	_run_matchup(hard, normal)
	print("")

	get_tree().quit()

func _run_matchup(blue_cfg: Array, red_cfg: Array) -> void:
	var blue_wins := 0
	var red_wins := 0
	var draws := 0
	var timeouts := 0
	var total_turns := 0

	for _g in range(NUM_GAMES):
		var result := _play_game(blue_cfg[0], blue_cfg[1], red_cfg[0], red_cfg[1])
		match result[0]:
			0: blue_wins += 1
			1: red_wins += 1
			2: draws += 1
			3: timeouts += 1
		total_turns += result[1]

	var label := "%-14s vs %-14s" % [blue_cfg[2], red_cfg[2]]
	print("  %s | Blue %3d (%4.1f%%) | Red %3d (%4.1f%%) | T/O %2d | Avg %3.0f" % [
		label, blue_wins, 100.0 * blue_wins / NUM_GAMES,
		red_wins, 100.0 * red_wins / NUM_GAMES,
		timeouts, float(total_turns) / NUM_GAMES])

func _play_game(depth_b: int, noise_b: int, depth_r: int, noise_r: int) -> Array:
	var board := BoardRules.make_board()
	var current := 0
	var last_move: Array = [[], []]
	var turn := 0

	var ai_b: RefCounted = null
	var ai_r: RefCounted = null
	if depth_b > 0:
		ai_b = _ai_script.new()
		ai_b.max_depth = depth_b
		ai_b.eval_noise = noise_b
	if depth_r > 0:
		ai_r = _ai_script.new()
		ai_r.max_depth = depth_r
		ai_r.eval_noise = noise_r

	while turn < MAX_TURNS:
		turn += 1

		for p in [0, 1]:
			if BoardRules.check_win(board, p):
				return [p, turn]

		if BoardRules.should_lift_antirepeat(board, current, last_move[current]):
			last_move[current] = []

		var forbidden := BoardRules.get_forbidden_reverse(last_move[current])
		var all_moves := BoardRules.get_all_moves(board, current, forbidden)

		if all_moves.is_empty():
			var other := 1 - current
			var yield_moves := BoardRules.get_yield_moves(board, other, current)
			if yield_moves.is_empty():
				return [2, turn]
			var ym: Array = yield_moves[randi() % yield_moves.size()]
			last_move[other] = [ym[0], ym[1]]
			board = BoardRules.apply_move(board, ym[0], ym[1])
			# Clear blocked player's anti-repeat after yield
			last_move[current] = []
			if BoardRules.should_lift_antirepeat(board, other, last_move[other]):
				last_move[other] = []
			continue

		var mv: Array
		var cur_ai: RefCounted = ai_b if current == 0 else ai_r
		if cur_ai != null:
			mv = cur_ai.get_best_move(board.duplicate(), current, forbidden)
			if mv.size() != 2:
				mv = all_moves[randi() % all_moves.size()]
		else:
			mv = all_moves[randi() % all_moves.size()]

		last_move[current] = [mv[0], mv[1]]
		board = BoardRules.apply_move(board, mv[0], mv[1])
		current = 1 - current

	return [3, MAX_TURNS]
