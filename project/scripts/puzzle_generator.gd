class_name PuzzleGenerator

enum PieceShape {
	SQUARE,
	JIGSAW,
}

## Slices an ImageTexture into a grid of piece textures with either square or jigsaw edges.
## Returns an Array[ImageTexture] ordered row-by-row, left-to-right.
static func generate_pieces(texture: ImageTexture, cols_rows: int, shape: PieceShape = PieceShape.SQUARE) -> Array[ImageTexture]:
	var image := texture.get_image()
	var image_size := image.get_size()
	var piece_w := int(image_size.x) / cols_rows
	var piece_h := int(image_size.y) / cols_rows

	if shape == PieceShape.JIGSAW:
		var edge_map := _generate_edge_map(cols_rows)
		return _generate_jigsaw_pieces(image, cols_rows, piece_w, piece_h, edge_map)

	return _generate_square_pieces(image, cols_rows, piece_w, piece_h)


static func _generate_square_pieces(image: Image, cols_rows: int, piece_w: int, piece_h: int) -> Array[ImageTexture]:
	var pieces: Array[ImageTexture] = []

	for row in range(cols_rows):
		for col in range(cols_rows):
			var piece_image := Image.create(piece_w, piece_h, false, image.get_format())
			piece_image.blit_rect(
				image,
				Rect2i(col * piece_w, row * piece_h, piece_w, piece_h),
				Vector2i.ZERO
			)
			pieces.append(ImageTexture.create_from_image(piece_image))

	return pieces


static func _generate_jigsaw_pieces(image: Image, cols_rows: int, piece_w: int, piece_h: int, edge_map: Array) -> Array[ImageTexture]:
	var pieces: Array[ImageTexture] = []

	for row in range(cols_rows):
		for col in range(cols_rows):
			var region_rect := Rect2i(col * piece_w, row * piece_h, piece_w, piece_h)
			var polygon := _build_piece_polygon(piece_w, piece_h, edge_map[row][col])
			var tex := create_piece_texture(image, region_rect, polygon)
			pieces.append(tex)

	return pieces


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

	var region_image := Image.create(region_size.x, region_size.y, false, image.get_format())
	region_image.blit_rect(image, region_rect, Vector2i.ZERO)
	if region_image.get_format() != Image.FORMAT_RGBA8:
		region_image.convert(Image.FORMAT_RGBA8)

	var mask_image := Image.create(region_size.x, region_size.y, false, Image.FORMAT_RGBA8)
	_fill_polygon(mask_image, polygon)

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
		var intersection_idx := 0
		while intersection_idx + 1 < intersections.size():
			var x_start := maxi(0, int(ceil(intersections[intersection_idx])))
			var x_end := mini(width - 1, int(floor(intersections[intersection_idx + 1])))
			for x in range(x_start, x_end + 1):
				image.set_pixel(x, y, Color.WHITE)
			intersection_idx += 2


static func _generate_edge_map(cols_rows: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var edge_map: Array = []
	for row in range(cols_rows):
		var row_edges: Array = []
		for col in range(cols_rows):
			row_edges.append({
				"top": 0,
				"right": 0,
				"bottom": 0,
				"left": 0,
			})
		edge_map.append(row_edges)

	for row in range(cols_rows):
		for col in range(cols_rows):
			var edges: Dictionary = edge_map[row][col]

			if col < cols_rows - 1:
				var right_edge := rng.randi_range(0, 1) == 0 ? 1 : -1
				edges["right"] = right_edge
				edge_map[row][col + 1]["left"] = -right_edge

			if row < cols_rows - 1:
				var bottom_edge := rng.randi_range(0, 1) == 0 ? 1 : -1
				edges["bottom"] = bottom_edge
				edge_map[row + 1][col]["top"] = -bottom_edge

	return edge_map


static func _build_piece_polygon(width: float, height: float, edges: Dictionary) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var tab_depth := min(width, height) * 0.18
	var inset := tab_depth + 1.0

	var corners: Array = [
		Vector2(inset, inset),
		Vector2(width - inset, inset),
		Vector2(width - inset, height - inset),
		Vector2(inset, height - inset),
	]

	var edge_names := ["top", "right", "bottom", "left"]
	for i in range(4):
		var start: Vector2 = corners[i]
		var finish: Vector2 = corners[(i + 1) % 4]
		polygon.append(start)
		_add_tab_points(polygon, start, finish, edges[edge_names[i]], tab_depth)

	return polygon


const TAB_FLAT_RATIO: float = 0.3
const TAB_NECK_MID: float = 0.35
const TAB_NECK_END: float = 0.4
const TAB_HEAD_EDGE: float = 0.45
const TAB_NECK_DEPTH: float = 0.5
const TAB_NECK_UPPER_DEPTH: float = 0.8
const TAB_HEAD_BULGE: float = 1.3
const TAB_BEZIER_SAMPLES: int = 5


static func _add_tab_points(polygon: PackedVector2Array, start: Vector2, finish: Vector2, edge_type: int, tab_depth: float) -> void:
	if edge_type == 0:
		return

	var along: Vector2 = finish - start
	var length := along.length()
	var t_vec := along.normalized()
	var normal := Vector2(t_vec.y, -t_vec.x)
	var depth := tab_depth if edge_type > 0 else -tab_depth

	var tab_start := start + t_vec * (length * TAB_FLAT_RATIO)
	var tab_end_ratio := 1.0 - TAB_FLAT_RATIO
	var head_left := TAB_HEAD_EDGE
	var head_right := 1.0 - TAB_HEAD_EDGE

	var b1_p0 := tab_start
	var b1_p1 := start + t_vec * (length * TAB_NECK_MID) + normal * (depth * TAB_NECK_DEPTH)
	var b1_p2 := start + t_vec * (length * TAB_NECK_END) + normal * (depth * TAB_NECK_UPPER_DEPTH)
	var b1_p3 := start + t_vec * (length * head_left) + normal * depth

	var b2_p0 := b1_p3
	var b2_p1 := start + t_vec * (length * head_left) + normal * (depth * TAB_HEAD_BULGE)
	var b2_p2 := start + t_vec * (length * head_right) + normal * (depth * TAB_HEAD_BULGE)
	var b2_p3 := start + t_vec * (length * head_right) + normal * depth

	var b3_p0 := b2_p3
	var b3_p1 := start + t_vec * (length * (1.0 - TAB_NECK_END)) + normal * (depth * TAB_NECK_UPPER_DEPTH)
	var b3_p2 := start + t_vec * (length * (1.0 - TAB_NECK_MID)) + normal * (depth * TAB_NECK_DEPTH)
	var b3_p3 := start + t_vec * (length * tab_end_ratio)

	polygon.append(tab_start)

	for i in range(1, TAB_BEZIER_SAMPLES + 1):
		var tv := float(i) / float(TAB_BEZIER_SAMPLES)
		polygon.append(_cubic_bezier(b1_p0, b1_p1, b1_p2, b1_p3, tv))

	for i in range(1, TAB_BEZIER_SAMPLES + 1):
		var tv := float(i) / float(TAB_BEZIER_SAMPLES)
		polygon.append(_cubic_bezier(b2_p0, b2_p1, b2_p2, b2_p3, tv))

	for i in range(1, TAB_BEZIER_SAMPLES + 1):
		var tv := float(i) / float(TAB_BEZIER_SAMPLES)
		polygon.append(_cubic_bezier(b3_p0, b3_p1, b3_p2, b3_p3, tv))


static func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
