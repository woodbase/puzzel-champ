extends RefCounted
class_name PuzzleGenerator

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
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func opposite(edge_type: EdgeType) -> EdgeType:
	return EdgeType.OUT if edge_type == EdgeType.IN else EdgeType.IN


func generate_edges(cols: int, rows: int) -> Array[PieceData]:
	var pieces: Array[PieceData] = []

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
	for row in range(rows):
		for col in range(cols):
			var piece: PieceData = pieces[row * cols + col]

			# Right edge (shared with neighbour's left edge)
			if col < cols - 1:
				var edge_type: EdgeType = EdgeType.IN if rng.randi() % 2 == 0 else EdgeType.OUT
				piece.edges["right"] = edge_type
				var neighbour: PieceData = pieces[row * cols + (col + 1)]
				neighbour.edges["left"] = opposite(edge_type)

			# Bottom edge (shared with neighbour's top edge)
			if row < rows - 1:
				var edge_type: EdgeType = EdgeType.IN if rng.randi() % 2 == 0 else EdgeType.OUT
				piece.edges["bottom"] = edge_type
				var neighbour: PieceData = pieces[(row + 1) * cols + col]
				neighbour.edges["top"] = opposite(edge_type)

	return pieces
