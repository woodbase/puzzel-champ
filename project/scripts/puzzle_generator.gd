class_name PuzzleGenerator

## Creates a puzzle piece texture by cutting a polygon-shaped region from an image.
##
## [param image] The source image to cut from.
## [param region_rect] The rectangular region within [param image] to extract.
## [param polygon] The polygon defining the piece shape, with coordinates relative
##   to the top-left corner of [param region_rect].
## [return] An [ImageTexture] containing only the polygon-shaped portion of the region.
##   Pixels outside the polygon are transparent.
static func create_piece_texture(image: Image, region_rect: Rect2i, polygon: PackedVector2Array) -> ImageTexture:
	var region_size := region_rect.size

	# Step 1: Extract region from image
	var region_image := Image.create(region_size.x, region_size.y, false, image.get_format())
	region_image.blit_rect(image, region_rect, Vector2i.ZERO)
	if region_image.get_format() != Image.FORMAT_RGBA8:
		region_image.convert(Image.FORMAT_RGBA8)

	# Step 2: Create mask image (transparent black by default)
	var mask_image := Image.create(region_size.x, region_size.y, false, Image.FORMAT_RGBA8)

	# Step 3: Draw polygon into mask (white opaque fill = visible area)
	_fill_polygon(mask_image, polygon)

	# Step 4: Apply mask to region
	var piece_image := Image.create(region_size.x, region_size.y, false, Image.FORMAT_RGBA8)
	piece_image.blit_rect_mask(region_image, mask_image, Rect2i(Vector2i.ZERO, region_size), Vector2i.ZERO)

	return ImageTexture.create_from_image(piece_image)


## Fills the interior of [param polygon] on [param image] with [constant Color.WHITE].
## Uses a scanline fill algorithm. Coordinates are in image-local space.
static func _fill_polygon(image: Image, polygon: PackedVector2Array) -> void:
	var n := polygon.size()
	if n < 3:
		return

	var width := image.get_width()
	var height := image.get_height()

	for y in range(height):
		var intersections: Array[float] = []
		for i in range(n):
			var p1 := polygon[i]
			var p2 := polygon[(i + 1) % n]
			if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y):
				var t := (float(y) - p1.y) / (p2.y - p1.y)
				intersections.append(p1.x + t * (p2.x - p1.x))
		intersections.sort()
		var i := 0
		while i + 1 < intersections.size():
			var x_start := maxi(0, int(ceil(intersections[i])))
			var x_end := mini(width - 1, int(floor(intersections[i + 1])))
			for x in range(x_start, x_end + 1):
				image.set_pixel(x, y, Color.WHITE)
			i += 2
