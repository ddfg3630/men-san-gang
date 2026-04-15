extends Control

func _ready() -> void:
	pass

func _on_pvp_button_pressed() -> void:
	GameConfig.vs_ai = false
	get_tree().change_scene_to_file("res://game.tscn")

func _on_ai_button_pressed() -> void:
	GameConfig.vs_ai = true
	GameConfig.ai_side = -1
	GameConfig.ai_difficulty = -1
	get_tree().change_scene_to_file("res://game.tscn")
