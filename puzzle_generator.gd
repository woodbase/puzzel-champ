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


func generate_edges(cols: int, rows: int) -> Array:
	var pieces: Array = []

	# Create all PieceData objects
	for row in range(rows):
		for col in range(cols):
			pieces.append(PieceData.new(Vector2i(col, row)))

	# Assign horizontal edges (shared between piece.right and right-neighbour.left)
	for row in range(rows):
		for col in range(cols - 1):
			var piece: PieceData = pieces[row * cols + col]
			var neighbour: PieceData = pieces[row * cols + col + 1]
			var edge_type: EdgeType = EdgeType.OUT if randi_range(0, 1) == 0 else EdgeType.IN
			piece.edges["right"] = edge_type
			neighbour.edges["left"] = EdgeType.IN if edge_type == EdgeType.OUT else EdgeType.OUT

	# Assign vertical edges (shared between piece.bottom and bottom-neighbour.top)
	for row in range(rows - 1):
		for col in range(cols):
			var piece: PieceData = pieces[row * cols + col]
			var neighbour: PieceData = pieces[(row + 1) * cols + col]
			var edge_type: EdgeType = EdgeType.OUT if randi_range(0, 1) == 0 else EdgeType.IN
			piece.edges["bottom"] = edge_type
			neighbour.edges["top"] = EdgeType.IN if edge_type == EdgeType.OUT else EdgeType.OUT

	return pieces
