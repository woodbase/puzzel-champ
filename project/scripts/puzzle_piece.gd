extends Control

## Emitted when the player drops this piece close enough to its correct position.
signal piece_placed

var grid_position: Vector2i = Vector2i.ZERO
var correct_position: Vector2 = Vector2.ZERO
var is_placed: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _snap_threshold: float = 40.0

@onready var texture_rect: TextureRect = $TextureRect


## Called by PuzzleBoard to initialise this piece.
func setup(tex: ImageTexture, grid_pos: Vector2i, correct_pos: Vector2, p_size: Vector2) -> void:
	grid_position = grid_pos
	correct_position = correct_pos
	_snap_threshold = min(p_size.x, p_size.y) * 0.4
	custom_minimum_size = p_size
	size = p_size
	texture_rect.texture = tex


func _gui_input(event: InputEvent) -> void:
	if is_placed:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position
			move_to_front()
			accept_event()
		elif _dragging:
			_dragging = false
			_try_snap()
			accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		position += event.relative
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_dragging = false
		_try_snap()
		get_viewport().set_input_as_handled()


func _try_snap() -> void:
	if position.distance_to(correct_position) <= _snap_threshold:
		position = correct_position
		is_placed = true
		piece_placed.emit()
