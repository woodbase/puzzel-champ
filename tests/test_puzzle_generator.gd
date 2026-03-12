extends GdUnitTestSuite

const PuzzleGenerator := preload("res://scripts/puzzle_generator.gd")


func test_generate_square_pieces_returns_expected_count_and_size() -> void:
	var img := Image.create(6, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.DIM_GRAY)
	var tex := ImageTexture.create_from_image(img)

	var pieces: Array = PuzzleGenerator.generate_pieces(tex, 2, PuzzleGenerator.PieceShape.SQUARE)

	assert_int(pieces.size()).is_equal(4)
	for piece in pieces:
		assert_object(piece).is_instanceof(ImageTexture)
		assert_int(piece.get_width()).is_equal(3)
		assert_int(piece.get_height()).is_equal(2)


func test_generate_pieces_resizes_to_grid_multiple() -> void:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6, 1.0))
	var tex := ImageTexture.create_from_image(img)

	var pieces: Array = PuzzleGenerator.generate_pieces(tex, 2, PuzzleGenerator.PieceShape.SQUARE)

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

	var tex := PuzzleGenerator.new().create_piece_texture(
		img,
		Rect2i(Vector2i.ZERO, Vector2i(2, 2)),
		polygon,
		PuzzleGenerator.PieceShape.SQUARE
	)
	var result := tex.get_image()

	assert_vector(result.get_size()).is_equal(Vector2(2, 2))
	assert_that(result.get_pixel(0, 0)).is_equal(Color.RED)
	assert_that(result.get_pixel(1, 0)).is_equal(Color.GREEN)
	assert_that(result.get_pixel(0, 1)).is_equal(Color.BLUE)
	assert_that(result.get_pixel(1, 1)).is_equal(Color.WHITE)
