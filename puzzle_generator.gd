extends Node

enum EdgeType {
	FLAT,
	IN,
	OUT,
}

class PieceData:
	var grid_pos: Vector2i
	var edges: Dictionary

	func _init(pos: Vector2i) -> void:
		grid_pos = pos
		edges = {
			"top": EdgeType.FLAT,
			"right": EdgeType.FLAT,
			"bottom": EdgeType.FLAT,
			"left": EdgeType.FLAT,
		}


func generate_edges(cols: int, rows: int) -> Array[PieceData]:
	var pieces: Array[PieceData] = []

	for row in range(rows):
		for col in range(cols):
			pieces.append(PieceData.new(Vector2i(col, row)))

	for row in range(rows):
		for col in range(cols):
			var piece: PieceData = pieces[row * cols + col]

			# Right edge (shared with neighbour's left edge)
			if col < cols - 1:
				var edge_type: EdgeType = EdgeType.IN if randi() % 2 == 0 else EdgeType.OUT
				piece.edges["right"] = edge_type
				var neighbour: PieceData = pieces[row * cols + (col + 1)]
				neighbour.edges["left"] = EdgeType.OUT if edge_type == EdgeType.IN else EdgeType.IN

			# Bottom edge (shared with neighbour's top edge)
			if row < rows - 1:
				var edge_type: EdgeType = EdgeType.IN if randi() % 2 == 0 else EdgeType.OUT
				piece.edges["bottom"] = edge_type
				var neighbour: PieceData = pieces[(row + 1) * cols + col]
				neighbour.edges["top"] = EdgeType.OUT if edge_type == EdgeType.IN else EdgeType.IN

	return pieces


# Generates a polygon for a puzzle piece with Bezier-curve tabs.
# tab_depth = piece_size * 0.25
# Edges are built in order: top, right, bottom, left.
# Returns a PackedVector2Array polygon.
func generate_piece_polygon(piece_data: PieceData, piece_size: float) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var tab_depth: float = piece_size * 0.25

	var corners: Array = [
		Vector2(0.0, 0.0),
		Vector2(piece_size, 0.0),
		Vector2(piece_size, piece_size),
		Vector2(0.0, piece_size),
	]

	var edge_names: Array = ["top", "right", "bottom", "left"]

	for i in range(4):
		var p_start: Vector2 = corners[i]
		var p_end: Vector2 = corners[(i + 1) % 4]
		polygon.append(p_start)
		_add_tab_points(polygon, p_start, p_end, piece_data.edges[edge_names[i]], tab_depth)

	return polygon


# Tab shape constants (fractions of edge length and tab depth).
const TAB_FLAT_RATIO: float = 0.3      # Flat section on each side of the tab [0..TAB_FLAT_RATIO] and [1-TAB_FLAT_RATIO..1]
const TAB_NECK_MID: float = 0.35      # Control point along edge for neck shoulder
const TAB_NECK_END: float = 0.4       # Where the neck reaches full depth along edge
const TAB_HEAD_EDGE: float = 0.45     # Edge of tab head along edge
const TAB_NECK_DEPTH: float = 0.5     # Depth fraction at neck shoulder
const TAB_NECK_UPPER_DEPTH: float = 0.8   # Depth fraction near the head
const TAB_HEAD_BULGE: float = 1.3     # Depth fraction at the head bulge control points
const TAB_BEZIER_SAMPLES: int = 5     # Number of samples per Bezier segment

# Appends intermediate Bezier-sampled tab points between p_start and p_end.
# For FLAT edges no points are added. For OUT/IN edges a tab knob is generated.
func _add_tab_points(polygon: PackedVector2Array, p_start: Vector2, p_end: Vector2, edge_type: EdgeType, tab_depth: float) -> void:
	if edge_type == EdgeType.FLAT:
		return

	var along: Vector2 = p_end - p_start
	var length: float = along.length()
	var t_vec: Vector2 = along.normalized()
	# Outward normal for a clockwise polygon (in screen-space, Y-down)
	var normal: Vector2 = Vector2(t_vec.y, -t_vec.x)

	# OUT = tab protrudes outward; IN = tab goes inward
	var depth: float = tab_depth if edge_type == EdgeType.OUT else -tab_depth

	# Tab is centred on the edge.
	# Flat sections: [0, TAB_FLAT_RATIO] and [1-TAB_FLAT_RATIO, 1]
	# Neck entry:   [TAB_FLAT_RATIO, TAB_HEAD_EDGE]        (cubic Bezier b1)
	# Head:         [TAB_HEAD_EDGE, 1-TAB_HEAD_EDGE]       (cubic Bezier b2)
	# Neck exit:    [1-TAB_HEAD_EDGE, 1-TAB_FLAT_RATIO]    (cubic Bezier b3)

	var tab_start: Vector2 = p_start + t_vec * (length * TAB_FLAT_RATIO)
	var tab_end_ratio: float = 1.0 - TAB_FLAT_RATIO
	var head_left: float = TAB_HEAD_EDGE
	var head_right: float = 1.0 - TAB_HEAD_EDGE

	# Neck entry control points
	var b1_p0: Vector2 = tab_start
	var b1_p1: Vector2 = p_start + t_vec * (length * TAB_NECK_MID) + normal * (depth * TAB_NECK_DEPTH)
	var b1_p2: Vector2 = p_start + t_vec * (length * TAB_NECK_END) + normal * (depth * TAB_NECK_UPPER_DEPTH)
	var b1_p3: Vector2 = p_start + t_vec * (length * head_left) + normal * depth

	# Head control points
	var b2_p0: Vector2 = b1_p3
	var b2_p1: Vector2 = p_start + t_vec * (length * head_left) + normal * (depth * TAB_HEAD_BULGE)
	var b2_p2: Vector2 = p_start + t_vec * (length * head_right) + normal * (depth * TAB_HEAD_BULGE)
	var b2_p3: Vector2 = p_start + t_vec * (length * head_right) + normal * depth

	# Neck exit control points
	var b3_p0: Vector2 = b2_p3
	var b3_p1: Vector2 = p_start + t_vec * (length * (1.0 - TAB_NECK_END)) + normal * (depth * TAB_NECK_UPPER_DEPTH)
	var b3_p2: Vector2 = p_start + t_vec * (length * (1.0 - TAB_NECK_MID)) + normal * (depth * TAB_NECK_DEPTH)
	var b3_p3: Vector2 = p_start + t_vec * (length * tab_end_ratio)

	# Add the start of the tab region (flat line from p_start to here is implicit)
	polygon.append(tab_start)

	# Sample each Bezier segment (skip t=0; it equals the previously added point)
	for i in range(1, TAB_BEZIER_SAMPLES + 1):
		var tv: float = float(i) / float(TAB_BEZIER_SAMPLES)
		polygon.append(_cubic_bezier(b1_p0, b1_p1, b1_p2, b1_p3, tv))

	for i in range(1, TAB_BEZIER_SAMPLES + 1):
		var tv: float = float(i) / float(TAB_BEZIER_SAMPLES)
		polygon.append(_cubic_bezier(b2_p0, b2_p1, b2_p2, b2_p3, tv))

	for i in range(1, TAB_BEZIER_SAMPLES + 1):
		var tv: float = float(i) / float(TAB_BEZIER_SAMPLES)
		polygon.append(_cubic_bezier(b3_p0, b3_p1, b3_p2, b3_p3, tv))

	# The last sample (t=1) equals b3_p3 = tab_end.
	# The remaining flat section from tab_end to p_end is implicit in the polygon.


# Evaluates a cubic Bezier curve at parameter t in [0, 1].
func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
