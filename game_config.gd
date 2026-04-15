extends Node
## Autoload singleton to pass config between scenes.

var vs_ai: bool = false
var ai_side: int = -1    # -1 = not chosen, 0 = blue, 1 = red
var ai_difficulty: int = -1  # 0=easy, 1=normal, 2=hard

func get_ai_depth() -> int:
	match ai_difficulty:
		0: return 2
		1: return 4
		2: return 6
		_: return 4

func get_ai_noise() -> int:
	## Random noise in evaluation — makes lower difficulties less predictable.
	match ai_difficulty:
		0: return 60
		1: return 15
		2: return 0
		_: return 15
