extends GdUnitTestSuite

const PuzzleGenerator := preload("res://scripts/puzzle_generator.gd")


func test_create_piece_texture_adds_padding_for_jigsaw_tab() -> void:
	var generator := PuzzleGenerator.new()

	var piece_data := PuzzleGenerator.PieceData.new()
	piece_data.edges["top"] = PuzzleGenerator.EdgeType.OUT

	var polygon := generator.generate_piece_polygon(
		piece_data,
		50,
		50,
		PuzzleGenerator.PieceShape.JIGSAW
	)
	var region := Rect2i(Vector2i.ZERO, Vector2i(50, 50))
	var image := Image.create(50, 50, false, Image.FORMAT_RGBA8)
	image.fill(Color.DIM_GRAY)

	var texture := generator.create_piece_texture(
		image,
		region,
		polygon,
		PuzzleGenerator.PieceShape.JIGSAW
	)

	var tab_depth := float(min(region.size.x, region.size.y)) * PuzzleGenerator.TAB_DEPTH_RATIO
	var expected_padding := int(ceil(tab_depth * PuzzleGenerator._TAB_HEAD_GAIN))

	assert_int(texture.get_width()).is_equal(region.size.x + expected_padding * 2)
	assert_int(texture.get_height()).is_equal(region.size.y + expected_padding * 2)

	var min_y := polygon[0].y
	for pt in polygon:
		min_y = minf(min_y, pt.y)

	assert_float(min_y).is_less_than(-tab_depth * 0.9)
	assert_float(min_y).is_greater_than(-tab_depth * 1.3)
