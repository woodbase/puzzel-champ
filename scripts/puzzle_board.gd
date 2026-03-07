extends Node2D

## Source image to slice into puzzle pieces. Assign this in the Godot editor.
@export var source_texture: Texture2D

## Number of columns in the puzzle grid.
@export var cols: int = 3

## Number of rows in the puzzle grid.
@export var rows: int = 2

## Label shown when all pieces are correctly placed.
@onready var complete_label: Label = $CompleteLabel

## PuzzlePiece scene instantiated for each piece.
const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")

## PuzzleGenerator script used to build the puzzle.
const PuzzleGeneratorScript = preload("res://scripts/puzzle_generator.gd")

## Total number of puzzle pieces managed by this board.
var _total_pieces: int = 0

## Number of pieces that have been snapped into place.
var _placed_pieces: int = 0

## Generator instance.
var _generator = null


func _ready() -> void:
	complete_label.visible = false
	_generator = PuzzleGeneratorScript.new()
	if source_texture != null:
		_build_puzzle()


## Builds the puzzle dynamically from source_texture using PuzzleGenerator.
## Steps: load image → calculate piece_size → generate_edges → for each
## PieceData generate polygon + texture + instantiate PuzzlePiece scene.
## Each piece stores its correct world position; pieces spawn randomly.
func _build_puzzle() -> void:
	var image := source_texture.get_image()
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var img_w := image.get_width()
	var img_h := image.get_height()

	# Calculate piece size (square pieces using the smaller cell dimension).
	var piece_size: int = min(img_w / cols, img_h / rows)

	var piece_data_array := _generator.generate_edges(cols, rows)
	_total_pieces = piece_data_array.size()
	_placed_pieces = 0

	var viewport_size := get_viewport_rect().size

	for pd in piece_data_array:
		var col: int = pd.grid_pos.x
		var row: int = pd.grid_pos.y

		# Generate jigsaw polygon and masked texture for this piece.
		var polygon := _generator.generate_piece_polygon(pd, piece_size)
		var region := Rect2i(col * piece_size, row * piece_size, piece_size, piece_size)
		var texture := _generator.create_piece_texture(image, region, polygon)

		# Correct world position is the centre of the grid cell.
		var correct_pos := Vector2(
			(col + 0.5) * piece_size,
			(row + 0.5) * piece_size
		)

		var piece := PIECE_SCENE.instantiate()
		add_child(piece)

		var sprite := piece.get_node("Sprite2D") as Sprite2D
		sprite.texture = texture

		# Give each piece its own collision shape sized to the piece.
		var col_shape := piece.get_node("CollisionShape2D") as CollisionShape2D
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(piece_size, piece_size)
		col_shape.shape = rect_shape

		piece.correct_position = correct_pos
		# Clamp random spawn so the piece (centred on position) stays on screen.
		var half := piece_size * 0.5
		piece.position = Vector2(
			randf_range(half, viewport_size.x - half),
			randf_range(half, viewport_size.y - half)
		)
		piece.piece_placed.connect(on_piece_placed)

	complete_label.visible = false


## Called by each PuzzlePiece when it snaps into place.
func on_piece_placed() -> void:
	_placed_pieces += 1
	if _placed_pieces >= _total_pieces and _total_pieces > 0:
		_show_complete()


## Displays the completion label.
func _show_complete() -> void:
	complete_label.visible = true
