extends Node

const PUZZLE_BOARD_PATH := "res://scenes/puzzle_board.tscn"


func _ready() -> void:
	if not GameState.resume_save:
		PuzzleConfig.apply_to_game_state()

	if GameState.image_texture == null:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		return

	get_tree().change_scene_to_file(PUZZLE_BOARD_PATH)
