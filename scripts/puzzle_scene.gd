extends Node

const PUZZLE_BOARD_PATH := "res://scenes/puzzle_board.tscn"


func _ready() -> void:
	PuzzleConfig.apply_to_game_state()

	if GameState.image_texture == null:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	get_tree().change_scene_to_file(PUZZLE_BOARD_PATH)
