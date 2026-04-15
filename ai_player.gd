extends RefCounted
## Minimax AI with alpha-beta pruning for 悶三缸.
## Difficulty is controlled by max_depth and eval_noise.

var max_depth: int = 4
var eval_noise: int = 0  # random ±noise added to leaf evaluation (0 = deterministic)

# ── Evaluation weights ──
const W_GOAL := 150        # opponent piece trapped in a goal circle
const W_SELF_GOAL := -150  # own piece stuck in a goal circle
const W_MOBILITY := 12     # per available move
const W_OPP_MOBILITY := -15 # per opponent move (restricting opponent is slightly more valuable)
const W_BLOCKED := -80     # fully blocked penalty

# Strategic value of each node position:
# Center nodes (4,7) are hubs — controlling them restricts the opponent.
# Edge nodes (3,5,6,8) are moderately valuable.
# Goal circles (0,1,2) are traps — being there is bad.
const NODE_VALUE: Array = [
	-20, -20, -20,  # 0,1,2: goal circles (bad to be in)
	 10,  25,  10,  # 3,4,5: top row (4=center hub, most connected)
	  5,  15,   5,  # 6,7,8: bottom row (7=center, fairly connected)
]

# How much value opponent pieces on goals give us (pushing them there)
const OPP_NODE_VALUE: Array = [
	 30,  30,  30,  # good if opponent is in goals
	-10, -25, -10,  # bad if opponent controls center
	 -5, -15,  -5,
]

func get_best_move(board: Array, ai_id: int, forbidden: Array = []) -> Array:
	var best_score := -99999
	var best_moves: Array = []  # collect all moves with best score for tie-breaking

	for i in range(BoardRules.NODE_COUNT):
		if board[i] != ai_id:
			continue
		var targets: Array = BoardRules.get_moves_filtered(board, i, forbidden)
		for t in targets:
			var ti: int = t
			var nb := BoardRules.apply_move(board, i, ti)
			var score: int = _minimax(nb, max_depth - 1, false, ai_id, -99999, 99999)
			if score > best_score:
				best_score = score
				best_moves = [[i, ti]]
			elif score == best_score:
				best_moves.append([i, ti])

	if best_moves.is_empty():
		return []
	# Randomize among equal-score moves to avoid deterministic play
	return best_moves[randi() % best_moves.size()]

func _minimax(board: Array, depth: int, maximizing: bool, ai_id: int, alpha: int, beta: int) -> int:
	var opponent := 1 - ai_id

	if BoardRules.check_win(board, ai_id):
		return 5000 + depth
	if BoardRules.check_win(board, opponent):
		return -5000 - depth
	if depth <= 0:
		return _evaluate(board, ai_id)

	var current := ai_id if maximizing else opponent

	if not BoardRules.has_any_move_raw(board, current):
		return _evaluate(board, ai_id) + (W_BLOCKED if maximizing else -W_BLOCKED)

	if maximizing:
		var best := -99999
		var moves := BoardRules.get_all_moves(board, current)
		for mv in moves:
			var nb := BoardRules.apply_move(board, mv[0], mv[1])
			var s: int = _minimax(nb, depth - 1, false, ai_id, alpha, beta)
			if s > best:
				best = s
			if s > alpha:
				alpha = s
			if beta <= alpha:
				return best
		return best
	else:
		var best := 99999
		var moves := BoardRules.get_all_moves(board, current)
		for mv in moves:
			var nb := BoardRules.apply_move(board, mv[0], mv[1])
			var s: int = _minimax(nb, depth - 1, true, ai_id, alpha, beta)
			if s < best:
				best = s
			if s < beta:
				beta = s
			if beta <= alpha:
				return best
		return best

func _evaluate(board: Array, ai_id: int) -> int:
	var opponent := 1 - ai_id
	var score := 0

	# Positional evaluation
	for i in range(BoardRules.NODE_COUNT):
		var nv: int = NODE_VALUE[i]
		var ov: int = OPP_NODE_VALUE[i]
		if board[i] == ai_id:
			score += nv
		elif board[i] == opponent:
			score += ov

	# Goal trapping (core win condition progress)
	for g in BoardRules.GOALS:
		var gi: int = g
		if board[gi] == opponent:
			score += W_GOAL
		if board[gi] == ai_id:
			score += W_SELF_GOAL

	# Mobility
	var ai_moves := BoardRules.get_all_moves(board, ai_id)
	var op_moves := BoardRules.get_all_moves(board, opponent)
	score += ai_moves.size() * W_MOBILITY
	score += op_moves.size() * W_OPP_MOBILITY

	# Noise for lower difficulties
	if eval_noise > 0:
		score += randi_range(-eval_noise, eval_noise)

	return score
