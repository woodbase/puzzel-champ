extends Area2D

## Emitted when this piece snaps into its correct position.
signal piece_placed

## The correct grid position this piece must snap to.
@export var correct_position: Vector2 = Vector2.ZERO

## Whether this piece has been snapped into its correct position.
var is_locked: bool = false

## Whether this piece is currently being dragged.
var _dragging: bool = false

## Offset between the piece's position and the mouse when drag starts.
var _drag_offset: Vector2 = Vector2.ZERO

## Default z_index when not dragging.
const DEFAULT_Z_INDEX: int = 0

## Elevated z_index while dragging so the piece renders on top.
const DRAG_Z_INDEX: int = 10

## Distance threshold in pixels for snapping to the correct position.
const SNAP_DISTANCE: float = 20.0


func _ready() -> void:
	input_pickable = true
	z_index = DEFAULT_Z_INDEX


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_locked:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_start_drag(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		_update_drag(get_global_mouse_position())

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_end_drag()


## Begins dragging the piece.
func _start_drag(mouse_pos: Vector2) -> void:
	_dragging = true
	_drag_offset = global_position - mouse_pos
	z_index = DRAG_Z_INDEX


## Moves the piece to follow the mouse.
func _update_drag(mouse_pos: Vector2) -> void:
	global_position = mouse_pos + _drag_offset


## Ends dragging; snaps and locks the piece if close enough to its target.
func _end_drag() -> void:
	_dragging = false
	z_index = DEFAULT_Z_INDEX

	var distance := global_position.distance_to(correct_position)
	if distance < SNAP_DISTANCE:
		global_position = correct_position
		is_locked = true
		piece_placed.emit()
