extends GdUnitTestSuite

const PuzzleGenerator := preload("res://scripts/puzzle_generator.gd")


func test_generate_square_pieces_returns_expected_count_and_size() -> void:
	var img := Image.create(6, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.DIM_GRAY)
	var tex := ImageTexture.create_from_image(img)

	var pieces := PuzzleGenerator.generate_pieces(tex, 2, PuzzleGenerator.PieceShape.SQUARE)

	assert_int(pieces.size()).is_equal(4)
	for piece in pieces:
		assert_object(piece).is_instanceof(ImageTexture)
		assert_int(piece.get_width()).is_equal(3)
		assert_int(piece.get_height()).is_equal(2)


func test_generate_pieces_resizes_to_grid_multiple() -> void:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6, 1.0))
	var tex := ImageTexture.create_from_image(img)

	var pieces := PuzzleGenerator.generate_pieces(tex, 2, PuzzleGenerator.PieceShape.SQUARE)

	assert_int(pieces.size()).is_equal(4)
	for piece in pieces:
		assert_int(piece.get_width()).is_equal(2)
		assert_int(piece.get_height()).is_equal(2)


func test_create_piece_texture_square_preserves_pixels() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.RED)
	img.set_pixel(1, 0, Color.GREEN)
	img.set_pixel(0, 1, Color.BLUE)
	img.set_pixel(1, 1, Color.WHITE)

	var polygon := PackedVector2Array([
		Vector2(0, 0),
		Vector2(2, 0),
		Vector2(2, 2),
		Vector2(0, 2),
	])

	var tex := PuzzleGenerator.create_piece_texture(
		img,
		Rect2i(Vector2i.ZERO, Vector2i(2, 2)),
		polygon,
		PuzzleGenerator.PieceShape.SQUARE
	)
	var result := tex.get_image()

	assert_vector2(result.get_size()).is_equal(Vector2(2, 2))
	assert_color(result.get_pixel(0, 0)).is_equal(Color.RED)
	assert_color(result.get_pixel(1, 0)).is_equal(Color.GREEN)
	assert_color(result.get_pixel(0, 1)).is_equal(Color.BLUE)
	assert_color(result.get_pixel(1, 1)).is_equal(Color.WHITE)


func test_generate_edges_is_seeded() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var generator := PuzzleGenerator.new()
	var edges_a := generator.generate_edges(2, 2, rng)

	rng.seed = 12345
	var generator_b := PuzzleGenerator.new()
	var edges_b := generator_b.generate_edges(2, 2, rng)

	assert_array(_edge_signatures(edges_a)).is_equal(_edge_signatures(edges_b))


func _edge_signatures(pieces: Array) -> Array:
	var result: Array = []
	for pd in pieces:
		result.append([
			pd.edges["top"],
			pd.edges["right"],
			pd.edges["bottom"],
			pd.edges["left"],
		])
	return result
