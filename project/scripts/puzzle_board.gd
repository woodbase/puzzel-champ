extends Control

## Emitted when every piece has been correctly placed.
signal puzzle_complete

const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")
const PuzzleGeneratorScript := preload("res://scripts/puzzle_generator.gd")

var _pieces: Array = []
var _grid_size: int = 0
var _piece_size: Vector2 = Vector2.ZERO
var _puzzle_offset: Vector2 = Vector2.ZERO
var _placed_count: int = 0


## Clears the current puzzle and builds a new one from the given texture.
func setup_puzzle(
		texture: ImageTexture,
		cols_rows: int,
		piece_shape: int = PuzzleGeneratorScript.PieceShape.SQUARE,
		allow_rotation: bool = false
	) -> void:
	for piece in _pieces:
		piece.queue_free()
	_pieces.clear()
	_placed_count = 0
	_grid_size = cols_rows

	# Fit the puzzle grid inside 90 % of the board, preserving image aspect ratio.
	var board_size := size
	var img_w := float(texture.get_width())
	var img_h := float(texture.get_height())
	var img_aspect := img_w / img_h if img_h > 0.0 else 1.0
	var board_aspect := board_size.x / board_size.y if board_size.y > 0.0 else 1.0

	var fit_w: float
	var fit_h: float
	if img_aspect > board_aspect:
		fit_w = board_size.x * 0.9
		fit_h = fit_w / img_aspect
	else:
		fit_h = board_size.y * 0.9
		fit_w = fit_h * img_aspect

	_piece_size = Vector2(fit_w / cols_rows, fit_h / cols_rows)
	_puzzle_offset = Vector2(
		(board_size.x - fit_w) * 0.5,
		(board_size.y - fit_h) * 0.5
	)

	var textures: Array[ImageTexture] = PuzzleGeneratorScript.generate_pieces(texture, cols_rows, piece_shape)

	for i in range(textures.size()):
		var col := i % cols_rows
		var row := i / cols_rows
		var correct_pos := _puzzle_offset + Vector2(col * _piece_size.x, row * _piece_size.y)

		var piece: Control = PIECE_SCENE.instantiate()
		add_child(piece)
		piece.setup(textures[i], Vector2i(col, row), correct_pos, _piece_size, allow_rotation)
		piece.position = Vector2(
			randf_range(0.0, board_size.x - _piece_size.x),
			randf_range(0.0, board_size.y - _piece_size.y)
		)
		piece.piece_placed.connect(_on_piece_placed)
		_pieces.append(piece)

	queue_redraw()


func _on_piece_placed() -> void:
	_placed_count += 1
	queue_redraw()
	if _placed_count >= _pieces.size():
		puzzle_complete.emit()


func _draw() -> void:
	# Dark background.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.15))

	if _grid_size > 0 and _piece_size != Vector2.ZERO:
		# Guide grid showing target positions.
		for row in range(_grid_size):
			for col in range(_grid_size):
				var rect := Rect2(
					_puzzle_offset + Vector2(col * _piece_size.x, row * _piece_size.y),
					_piece_size
				)
				draw_rect(rect, Color(0.35, 0.35, 0.35, 0.8), false, 1.5)
