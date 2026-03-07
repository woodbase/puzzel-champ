extends Node2D

var cols: int = 4
var rows: int = 4
var piece_size: Vector2 = Vector2.ZERO
var pieces: Array[Node2D] = []


func _ready() -> void:
	cols = GameState.cols
	rows = GameState.rows
	if GameState.image_texture == null:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	_setup_board()


func _setup_board() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var board_margin: float = 20.0
	var usable_width: float = viewport_size.x - board_margin * 2.0
	var usable_height: float = viewport_size.y - board_margin * 2.0
	var piece_w: float = usable_width / float(cols)
	var piece_h: float = usable_height / float(rows)
	piece_size = Vector2(piece_w, piece_h)
	_create_pieces()
	_shuffle_pieces()


func _create_pieces() -> void:
	var texture: ImageTexture = GameState.image_texture
	var img: Image = texture.get_image()
	var img_w: float = float(img.get_width())
	var img_h: float = float(img.get_height())
	var total: int = cols * rows
	for i: int in range(total):
		var col: int = i % cols
		var row: int = i / cols
		var src_rect := Rect2(
			col * img_w / float(cols),
			row * img_h / float(rows),
			img_w / float(cols),
			img_h / float(rows)
		)
		var piece_texture := ImageTexture.create_from_image(
			img.get_region(src_rect)
		)
		var piece := _create_piece_node(piece_texture, i, col, row)
		pieces.append(piece)
		add_child(piece)


func _create_piece_node(texture: ImageTexture, index: int, col: int, row: int) -> Node2D:
	var piece := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	piece.add_child(sprite)
	piece.set_meta("index", index)
	piece.set_meta("correct_col", col)
	piece.set_meta("correct_row", row)
	var target_pos := Vector2(float(col) * piece_size.x + 20.0, float(row) * piece_size.y + 20.0)
	piece.set_meta("target_pos", target_pos)
	piece.position = target_pos
	return piece


func _shuffle_pieces() -> void:
	var total: int = pieces.size()
	for i: int in range(total - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var pos_i: Vector2 = pieces[i].position
		pieces[i].position = pieces[j].position
		pieces[j].position = pos_i


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
