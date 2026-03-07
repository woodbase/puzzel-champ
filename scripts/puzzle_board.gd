extends Node2D

## Label shown when all pieces are correctly placed.
@onready var complete_label: Label = $CompleteLabel

## Total number of puzzle pieces managed by this board.
var _total_pieces: int = 0

## Number of pieces that have been snapped into place.
var _placed_pieces: int = 0


func _ready() -> void:
	complete_label.visible = false
	var pieces := get_tree().get_nodes_in_group("puzzle_pieces")
	_total_pieces = pieces.size()
	for piece in pieces:
		piece.piece_placed.connect(on_piece_placed)


## Called by each PuzzlePiece when it snaps into place.
func on_piece_placed() -> void:
	_placed_pieces += 1
	if _placed_pieces >= _total_pieces and _total_pieces > 0:
		_show_complete()


## Displays the completion label.
func _show_complete() -> void:
	complete_label.visible = true
