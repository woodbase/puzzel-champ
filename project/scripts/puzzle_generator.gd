class_name PuzzleGenerator


## Slices an ImageTexture into a grid of piece textures.
## Returns an Array[ImageTexture] ordered row-by-row, left-to-right.
static func generate_pieces(texture: ImageTexture, cols_rows: int) -> Array[ImageTexture]:
	var pieces: Array[ImageTexture] = []
	var image := texture.get_image()
	var image_size := image.get_size()
	var piece_w := int(image_size.x) / cols_rows
	var piece_h := int(image_size.y) / cols_rows

	for row in range(cols_rows):
		for col in range(cols_rows):
			var piece_image := Image.create(piece_w, piece_h, false, image.get_format())
			piece_image.blit_rect(
				image,
				Rect2i(col * piece_w, row * piece_h, piece_w, piece_h),
				Vector2i(0, 0)
			)
			pieces.append(ImageTexture.create_from_image(piece_image))

	return pieces
