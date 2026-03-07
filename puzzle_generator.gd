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
