class_name BoardRules
## Pure game rules engine for 悶三缸. Zero rendering dependency.
## All functions are static — no instance state.

const NODE_COUNT := 9

const ADJ: Dictionary = {
	0: [3],
	1: [4],
	2: [5],
	3: [0, 4, 6],
	4: [1, 3, 5, 7],
	5: [2, 4, 8],
	6: [3, 7],
	7: [4, 6, 8],
	8: [5, 7],
}

const GOALS: Array = [0, 1, 2]       # top circles (opponent gets pushed here)
const MIDDLE_ROW: Array = [3, 4, 5]  # winner must occupy this row to seal the win

# ── Board creation ──

static func make_board() -> Array:
	## Returns initial board: player 0 on left column, player 1 on right.
	var b: Array = [-1, -1, -1, -1, -1, -1, -1, -1, -1]
	b[0] = 0; b[3] = 0; b[6] = 0
	b[2] = 1; b[5] = 1; b[8] = 1
	return b

static func apply_move(board: Array, from: int, to: int) -> Array:
	## Returns a new board with the move applied. Does NOT mutate the input.
	var b: Array = board.duplicate()
	b[to] = b[from]
	b[from] = -1
	return b

# ── Move generation ──

static func get_moves(board: Array, node: int) -> Array:
	## Raw valid moves for a piece at node (ignoring anti-repeat).
	if node < 0 or node >= NODE_COUNT:
		return []
	var result: Array = []
	var neighbors: Array = ADJ[node]
	for n in neighbors:
		var ni: int = n
		if board[ni] == -1:
			result.append(ni)
	return result

static func get_moves_filtered(board: Array, node: int, forbidden: Array) -> Array:
	## Valid moves excluding the forbidden reverse [from, to].
	if node < 0 or node >= NODE_COUNT:
		return []
	var result: Array = []
	var neighbors: Array = ADJ[node]
	for n in neighbors:
		var ni: int = n
		if board[ni] != -1:
			continue
		if forbidden.size() == 2 and node == forbidden[0] and ni == forbidden[1]:
			continue
		result.append(ni)
	return result

static func get_all_moves(board: Array, player: int, forbidden: Array = []) -> Array:
	## All [from, to] pairs for player, respecting anti-repeat.
	var result: Array = []
	for i in range(NODE_COUNT):
		if board[i] != player:
			continue
		var targets: Array = get_moves_filtered(board, i, forbidden) if forbidden.size() == 2 else get_moves(board, i)
		for t in targets:
			result.append([i, t])
	return result

# ── Anti-repeat ──

static func get_forbidden_reverse(last_move: Array) -> Array:
	## Given a last move [from, to], returns the forbidden reverse [to, from].
	if last_move.size() == 2:
		return [last_move[1], last_move[0]]
	return []

static func should_lift_antirepeat(board: Array, player: int, last_move: Array) -> bool:
	## Returns true if player is ONLY blocked because of anti-repeat.
	## (Has no filtered moves, but has raw moves.)
	var forbidden := get_forbidden_reverse(last_move)
	if forbidden.is_empty():
		return false
	var filtered := get_all_moves(board, player, forbidden)
	if not filtered.is_empty():
		return false  # has moves even with restriction
	var raw := get_all_moves(board, player)
	return not raw.is_empty()  # blocked only by restriction

# ── Blocking ──

static func is_blocked(board: Array, player: int, last_move: Array = []) -> bool:
	## Player has no valid moves (considering anti-repeat, but auto-lifting if needed).
	var forbidden := get_forbidden_reverse(last_move)
	var moves := get_all_moves(board, player, forbidden)
	if not moves.is_empty():
		return false
	# Check if blocked only by anti-repeat — that doesn't count
	var raw := get_all_moves(board, player)
	return raw.is_empty()

static func has_any_move_raw(board: Array, player: int) -> bool:
	## Quick check: does player have any move ignoring anti-repeat?
	for i in range(NODE_COUNT):
		if board[i] != player:
			continue
		var neighbors: Array = ADJ[i]
		for n in neighbors:
			var ni: int = n
			if board[ni] == -1:
				return true
	return false

# ── Yield ──

static func get_yield_moves(board: Array, yielder: int, blocked: int) -> Array:
	## All [from, to] for yielder that actually unblock the blocked player.
	var result: Array = []
	var raw := get_all_moves(board, yielder)
	for mv in raw:
		var from: int = mv[0]
		var to: int = mv[1]
		var sim := apply_move(board, from, to)
		if has_any_move_raw(sim, blocked):
			result.append(mv)
	return result

# ── Win condition ──

static func check_win(board: Array, player: int) -> bool:
	## Player wins when:
	## 1. ALL opponent pieces are in goal circles [0,1,2]
	## 2. AND all player pieces occupy the middle row [3,4,5] (sealing the win)
	## This ensures the winner makes the final move to complete the lockdown.
	var opponent := 1 - player
	for g in GOALS:
		var gi: int = g
		if board[gi] != opponent:
			return false
	for m in MIDDLE_ROW:
		var mi: int = m
		if board[mi] != player:
			return false
	return true

# ── Validation (for tests) ──

static func validate_board(board: Array) -> String:
	## Returns "" if valid, or an error message.
	if board.size() != NODE_COUNT:
		return "Board size is %d, expected %d" % [board.size(), NODE_COUNT]
	var count := [0, 0]
	for i in range(NODE_COUNT):
		var v: int = board[i]
		if v == 0:
			count[0] += 1
		elif v == 1:
			count[1] += 1
		elif v != -1:
			return "Invalid value %d at node %d" % [v, i]
	if count[0] != 3:
		return "Player 0 has %d pieces (expected 3)" % count[0]
	if count[1] != 3:
		return "Player 1 has %d pieces (expected 3)" % count[1]
	return ""
