extends RefCounted

## Enum for puzzle piece edge types.
enum EdgeType {
	FLAT,
	IN,
	OUT
}

## Holds the grid position and edge types for one puzzle piece.
class PieceData:
	var grid_pos: Vector2i
	var edges := {
		"top": EdgeType.FLAT,
		"right": EdgeType.FLAT,
		"bottom": EdgeType.FLAT,
		"left": EdgeType.FLAT
	}


## Generates PieceData for all pieces in a cols x rows grid.
## Border edges are FLAT; shared internal edges are randomly IN or OUT
## with the neighbour always receiving the opposite value.
func generate_edges(cols: int, rows: int) -> Array:
	var pieces := []
	for row in range(rows):
		for col in range(cols):
			var pd := PieceData.new()
			pd.grid_pos = Vector2i(col, row)
			pieces.append(pd)

	for row in range(rows):
		for col in range(cols):
			var piece: PieceData = pieces[row * cols + col]

			# Right edge (shared with right neighbour's left edge).
			if col < cols - 1:
				var et: int = EdgeType.IN if randi() % 2 == 0 else EdgeType.OUT
				piece.edges["right"] = et
				var neighbour: PieceData = pieces[row * cols + (col + 1)]
				neighbour.edges["left"] = EdgeType.OUT if et == EdgeType.IN else EdgeType.IN

			# Bottom edge (shared with lower neighbour's top edge).
			if row < rows - 1:
				var et: int = EdgeType.IN if randi() % 2 == 0 else EdgeType.OUT
				piece.edges["bottom"] = et
				var neighbour: PieceData = pieces[(row + 1) * cols + col]
				neighbour.edges["top"] = EdgeType.OUT if et == EdgeType.IN else EdgeType.IN

	return pieces


## Fraction of piece_size used as the tab protrusion depth.
const TAB_DEPTH_RATIO: float = 0.25

## Generates a jigsaw polygon for the given piece.
## tab_depth = piece_size * TAB_DEPTH_RATIO; edges are built in order: top, right, bottom, left.
## Returns a PackedVector2Array polygon.
func generate_piece_polygon(piece_data: PieceData, piece_size: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var tab_depth: float = piece_size * TAB_DEPTH_RATIO
	var s: float = float(piece_size)

	var corners := [
		Vector2(0.0, 0.0),
		Vector2(s, 0.0),
		Vector2(s, s),
		Vector2(0.0, s),
	]
	var edge_names := ["top", "right", "bottom", "left"]

	for i in range(4):
		var p_start: Vector2 = corners[i]
		var p_end: Vector2 = corners[(i + 1) % 4]
		polygon.append(p_start)
		_add_tab_points(polygon, p_start, p_end, piece_data.edges[edge_names[i]], tab_depth)

	return polygon


# Tab shape constants (fractions of edge length / depth).
const _TAB_FLAT: float = 0.3
const _TAB_NECK_MID: float = 0.35
const _TAB_NECK_END: float = 0.4
const _TAB_HEAD_EDGE: float = 0.45
const _TAB_NECK_DEPTH: float = 0.5
const _TAB_NECK_UPPER: float = 0.8
const _TAB_HEAD_BULGE: float = 1.3
const _BEZIER_STEPS: int = 5


# Appends Bezier-sampled tab points between p_start and p_end.
func _add_tab_points(polygon: PackedVector2Array, p_start: Vector2, p_end: Vector2, edge_type: int, tab_depth: float) -> void:
	if edge_type == EdgeType.FLAT:
		return

	var along: Vector2 = p_end - p_start
	var length: float = along.length()
	var t_vec: Vector2 = along.normalized()
	# Outward normal for a clockwise polygon in screen-space (Y-down).
	var normal: Vector2 = Vector2(t_vec.y, -t_vec.x)
	var depth: float = tab_depth if edge_type == EdgeType.OUT else -tab_depth

	var tab_start := p_start + t_vec * (length * _TAB_FLAT)
	var head_left := _TAB_HEAD_EDGE
	var head_right := 1.0 - _TAB_HEAD_EDGE

	var b1_p0 := tab_start
	var b1_p1 := p_start + t_vec * (length * _TAB_NECK_MID) + normal * (depth * _TAB_NECK_DEPTH)
	var b1_p2 := p_start + t_vec * (length * _TAB_NECK_END) + normal * (depth * _TAB_NECK_UPPER)
	var b1_p3 := p_start + t_vec * (length * head_left) + normal * depth

	var b2_p0 := b1_p3
	var b2_p1 := p_start + t_vec * (length * head_left) + normal * (depth * _TAB_HEAD_BULGE)
	var b2_p2 := p_start + t_vec * (length * head_right) + normal * (depth * _TAB_HEAD_BULGE)
	var b2_p3 := p_start + t_vec * (length * head_right) + normal * depth

	var b3_p0 := b2_p3
	var b3_p1 := p_start + t_vec * (length * (1.0 - _TAB_NECK_END)) + normal * (depth * _TAB_NECK_UPPER)
	var b3_p2 := p_start + t_vec * (length * (1.0 - _TAB_NECK_MID)) + normal * (depth * _TAB_NECK_DEPTH)
	var b3_p3 := p_start + t_vec * (length * (1.0 - _TAB_FLAT))

	polygon.append(tab_start)
	for i in range(1, _BEZIER_STEPS + 1):
		var tv: float = float(i) / float(_BEZIER_STEPS)
		polygon.append(_cubic_bezier(b1_p0, b1_p1, b1_p2, b1_p3, tv))
	for i in range(1, _BEZIER_STEPS + 1):
		var tv: float = float(i) / float(_BEZIER_STEPS)
		polygon.append(_cubic_bezier(b2_p0, b2_p1, b2_p2, b2_p3, tv))
	for i in range(1, _BEZIER_STEPS + 1):
		var tv: float = float(i) / float(_BEZIER_STEPS)
		polygon.append(_cubic_bezier(b3_p0, b3_p1, b3_p2, b3_p3, tv))


# Evaluates a cubic Bezier curve at parameter t in [0, 1].
func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


## Creates a masked puzzle-piece texture from the source image.
## Steps: (1) extract region, (2) create mask, (3) draw polygon into mask,
## (4) apply mask via blit_rect_mask. Returns the resulting ImageTexture.
func create_piece_texture(image: Image, region: Rect2i, polygon: PackedVector2Array) -> ImageTexture:
	var region_size := region.size

	# Step 1: Extract region from source image.
	var region_image := Image.create(region_size.x, region_size.y, false, image.get_format())
	region_image.blit_rect(image, region, Vector2i.ZERO)
	if region_image.get_format() != Image.FORMAT_RGBA8:
		region_image.convert(Image.FORMAT_RGBA8)

	# Step 2: Create mask image (transparent black by default).
	var mask_image := Image.create(region_size.x, region_size.y, false, Image.FORMAT_RGBA8)

	# Step 3: Draw polygon shape into mask (white = visible).
	_fill_polygon(mask_image, polygon)

	# Step 4: Apply mask to region image.
	var piece_image := Image.create(region_size.x, region_size.y, false, Image.FORMAT_RGBA8)
	piece_image.blit_rect_mask(region_image, mask_image, Rect2i(Vector2i.ZERO, region_size), Vector2i.ZERO)

	return ImageTexture.create_from_image(piece_image)


# Fills the interior of polygon on image with white using a scanline algorithm.
func _fill_polygon(image: Image, polygon: PackedVector2Array) -> void:
	var n := polygon.size()
	if n < 3:
		return

	var width := image.get_width()
	var height := image.get_height()

	# Reuse a single array across scanlines to reduce per-line allocations.
	var intersections: Array[float] = []

	for y in range(height):
		intersections.clear()
		for i in range(n):
			var p1 := polygon[i]
			var p2 := polygon[(i + 1) % n]
			if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y):
				var t := (float(y) - p1.y) / (p2.y - p1.y)
				intersections.append(p1.x + t * (p2.x - p1.x))
		intersections.sort()
		var idx := 0
		while idx + 1 < intersections.size():
			var x_start := maxi(0, int(ceil(intersections[idx])))
			var x_end := mini(width - 1, int(floor(intersections[idx + 1])))
			for x in range(x_start, x_end + 1):
				image.set_pixel(x, y, Color.WHITE)
			idx += 2
