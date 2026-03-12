extends RefCounted

## Enum for puzzle piece shapes.
enum PieceShape {
	SQUARE,
	JIGSAW
}

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
const TAB_DEPTH_RATIO: float = 0.26

## Generates a polygon for the given piece.
## piece_w and piece_h are the cell dimensions in image-space pixels (may differ
## when the source image has a non-square aspect ratio).
## shape selects the piece style: PieceShape.SQUARE or PieceShape.JIGSAW.
## Returns a PackedVector2Array polygon.
func generate_piece_polygon(piece_data: PieceData, piece_w: int, piece_h: int, shape: int = PieceShape.JIGSAW) -> PackedVector2Array:
	if shape == PieceShape.SQUARE:
		return _square_polygon(piece_w, piece_h)
	return _jigsaw_polygon(piece_data, piece_w, piece_h)


## Returns a rectangular polygon covering the full cell (no tabs).
func _square_polygon(piece_w: int, piece_h: int) -> PackedVector2Array:
	var w := float(piece_w)
	var h := float(piece_h)
	var polygon := PackedVector2Array()
	polygon.append(Vector2(0.0, 0.0))
	polygon.append(Vector2(w, 0.0))
	polygon.append(Vector2(w, h))
	polygon.append(Vector2(0.0, h))
	return polygon


## Generates a jigsaw polygon for the given piece.
## tab_depth = min(piece_w, piece_h) * TAB_DEPTH_RATIO; edges are built in order: top, right, bottom, left.
func _jigsaw_polygon(piece_data: PieceData, piece_w: int, piece_h: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var tab_depth: float = min(piece_w, piece_h) * TAB_DEPTH_RATIO
	var w: float = float(piece_w)
	var h: float = float(piece_h)

	var corners := [
		Vector2(0.0, 0.0),
		Vector2(w, 0.0),
		Vector2(w, h),
		Vector2(0.0, h),
	]
	var edge_names := ["top", "right", "bottom", "left"]

	for i in range(4):
		var p_start: Vector2 = corners[i]
		var p_end: Vector2 = corners[(i + 1) % 4]
		polygon.append(p_start)
		_add_tab_points(polygon, p_start, p_end, piece_data.edges[edge_names[i]], tab_depth)

	return polygon


## Tab shape constants. Values are fractions of edge length / tab depth.
const _TAB_FLAT: float = 0.18
const _TAB_NECK_PINCH: float = 0.55
const _TAB_HEAD_GAIN: float = 1.1
## Sample points along each edge to approximate the rounded tab profile.
const _TAB_SAMPLES: int = 18
## Reduced samples on mobile to keep polygon complexity lower.
const _TAB_SAMPLES_MOBILE: int = 12


# Appends rounded tab points between p_start and p_end.
func _add_tab_points(polygon: PackedVector2Array, p_start: Vector2, p_end: Vector2, edge_type: int, tab_depth: float) -> void:
	if edge_type == EdgeType.FLAT:
		return

	# Use fewer curve segments on mobile to reduce polygon vertex count and
	# the per-piece scanline fill cost without noticeably changing piece shape.
	var steps: int = _TAB_SAMPLES_MOBILE if GameState.is_mobile else _TAB_SAMPLES

	var along: Vector2 = p_end - p_start
	var length: float = along.length()
	var t_vec: Vector2 = along.normalized()
	# Outward normal for a clockwise polygon in screen-space (Y-down).
	var normal: Vector2 = Vector2(t_vec.y, -t_vec.x)
	var depth: float = tab_depth if edge_type == EdgeType.OUT else -tab_depth

	var tab_start_s: float = _TAB_FLAT
	var tab_end_s: float = 1.0 - _TAB_FLAT
	var tab_width: float = tab_end_s - tab_start_s

	for i in range(1, steps):
		var s: float = float(i) / float(steps)
		var y_offset: float = 0.0

		if s >= tab_start_s and s <= tab_end_s:
			var u: float = (s - tab_start_s) / tab_width  # Normalised position across the tab (0..1).
			var dome: float = sin(u * PI)                 # Smooth rise/fall with zero slope at both ends.
			var neck: float = lerp(_TAB_NECK_PINCH, 1.0, dome)  # Slight waist near the tab base.
			var head: float = lerp(1.0, _TAB_HEAD_GAIN, dome)   # Rounder head at the peak.
			y_offset = depth * dome * neck * head

		var point := p_start + t_vec * (length * s) + normal * y_offset
		polygon.append(point)


## Creates a masked puzzle-piece texture from the source image.
## For jigsaw pieces the texture is expanded uniformly by the maximum OUT-tab
## protrusion so that tabs are not clipped. Square pieces use zero padding and
## the texture matches the cell size exactly.
## For jigsaw pieces the cell is centred within the padded texture, so callers
## can position a centred Sprite2D at the cell's world-space centre.
##
## Steps: (1) expand region by padding, (2) extract expanded pixels,
## (3) create mask, (4) shift polygon into padded space + fill,
## (5) apply mask via blit_rect_mask. Returns the resulting ImageTexture.
func create_piece_texture(image: Image, region: Rect2i, polygon: PackedVector2Array, shape: int = PieceShape.JIGSAW) -> ImageTexture:
	# Padding = maximum extent an OUT tab protrudes beyond the piece bounding box.
	var padding: int
	if shape == PieceShape.JIGSAW:
		var tab_depth := float(min(region.size.x, region.size.y)) * TAB_DEPTH_RATIO
		padding = int(ceil(tab_depth * _TAB_HEAD_GAIN))
	else:
		padding = 0

	var padded_size := Vector2i(region.size.x + 2 * padding, region.size.y + 2 * padding)

	# The desired source rect in image-space (may partially exceed image bounds).
	var padded_in_src := Rect2i(region.position - Vector2i(padding, padding), padded_size)
	var img_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var clamped_src := padded_in_src.intersection(img_rect)

	# Step 1: Extract expanded region (transparent where out of bounds).
	var region_image := Image.create(padded_size.x, padded_size.y, false, Image.FORMAT_RGBA8)
	if clamped_src.size.x > 0 and clamped_src.size.y > 0:
		var dst_offset := Vector2i(
			clamped_src.position.x - padded_in_src.position.x,
			clamped_src.position.y - padded_in_src.position.y
		)
		region_image.blit_rect(image, clamped_src, dst_offset)

	# Step 2: Create mask image at padded size (transparent black by default).
	var mask_image := Image.create(padded_size.x, padded_size.y, false, Image.FORMAT_RGBA8)

	# Step 3: Shift polygon by padding so it aligns with the padded image, then fill.
	var poly_offset := Vector2(float(padding), float(padding))
	var offset_polygon := PackedVector2Array()
	for pt in polygon:
		offset_polygon.append(pt + poly_offset)
	_fill_polygon(mask_image, offset_polygon)

	# Step 4: Apply mask to region image.
	var piece_image := Image.create(padded_size.x, padded_size.y, false, Image.FORMAT_RGBA8)
	piece_image.blit_rect_mask(region_image, mask_image, Rect2i(Vector2i.ZERO, padded_size), Vector2i.ZERO)

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
			# fill_rect is a single C++ call and vastly outperforms a GDScript
			# pixel loop, especially for wide spans on mobile hardware.
			if x_end >= x_start:
				image.fill_rect(Rect2i(x_start, y, x_end - x_start + 1, 1), Color.WHITE)
			idx += 2
