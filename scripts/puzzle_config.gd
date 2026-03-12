extends Node

const DIFFICULTIES: Dictionary = {
	"easy": {"cols": 3, "rows": 2},
	"medium": {"cols": 4, "rows": 3},
	"hard": {"cols": 6, "rows": 4},
	"expert": {"cols": 8, "rows": 6},
}

var scene: Texture2D = null
var scene_path: String = ""
var gallery_index: int = -1
var difficulty: String = "medium"
var shape: String = "jigsaw"


func apply_to_game_state() -> void:
	if scene != null:
		GameState.image_texture = scene
	GameState.image_path = scene_path
	GameState.gallery_index = gallery_index
	GameState.piece_shape = shape
	GameState.difficulty_explicitly_set = true

	var diff: Dictionary = DIFFICULTIES.get(difficulty, DIFFICULTIES["medium"])
	GameState.cols = int(diff.get("cols", GameState.cols))
	GameState.rows = int(diff.get("rows", GameState.rows))
