extends Control

## Emitted when the player drops this piece close enough to its correct position.
signal piece_placed

var grid_position: Vector2i = Vector2i.ZERO
var correct_position: Vector2 = Vector2.ZERO
var is_placed: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _snap_threshold: float = 40.0
var _rotation_enabled: bool = false
var _rotation_snap_tolerance: float = 8.0
const ROTATION_STEP_DEG: float = 90.0

## Whether visual snap feedback is enabled (set by PuzzleBoard).
var feedback_visual: bool = true

## Whether haptic snap feedback is enabled (set by PuzzleBoard).
var feedback_haptic: bool = true

@onready var texture_rect: TextureRect = $TextureRect


## Called by PuzzleBoard to initialise this piece.
func setup(
		tex: ImageTexture,
		grid_pos: Vector2i,
		correct_pos: Vector2,
		p_size: Vector2,
		allow_rotation: bool = false
	) -> void:
	grid_position = grid_pos
	correct_position = correct_pos
	_snap_threshold = min(p_size.x, p_size.y) * 0.4
	custom_minimum_size = p_size
	size = p_size
	texture_rect.texture = tex
	pivot_offset = p_size * 0.5
	_rotation_enabled = allow_rotation
	if _rotation_enabled:
		rotation_degrees = ROTATION_STEP_DEG * randi_range(0, 3)


func _gui_input(event: InputEvent) -> void:
	if is_placed:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _rotation_enabled:
			_rotate_piece()
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
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
	if position.distance_to(correct_position) <= _snap_threshold and _rotation_correct():
		position = correct_position
		if _rotation_enabled:
			rotation_degrees = 0.0
		is_placed = true
		if feedback_haptic:
			Input.vibrate_handheld(50)
		if feedback_visual:
			_play_snap_animation()
		piece_placed.emit()


## Plays a brief scale-bounce and colour-flash animation on the piece.
func _play_snap_animation() -> void:
	# Use a single tween so both phases run sequentially without needing `await`.
	# Animate `self` so the pivot_offset (set to centre in setup()) is respected.
	var tween := create_tween()

	# Phase 1: scale up and flash to gold (0.10 s), in parallel.
	tween.tween_property(self, "scale", Vector2(1.22, 1.22), 0.10)
	tween.parallel().tween_property(self, "modulate", Color(1.5, 1.3, 0.3, 1.0), 0.10)

	# Phase 2: settle back to normal (0.15 s), in parallel after phase 1 completes.
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _rotate_piece() -> void:
	rotation_degrees = fposmod(rotation_degrees + ROTATION_STEP_DEG, 360.0)
	if _dragging:
		_drag_offset = get_local_mouse_position()


func _rotation_correct() -> bool:
	if not _rotation_enabled:
		return true

	var angle := fposmod(rotation_degrees, 360.0)
	var distance_to_zero := min(angle, 360.0 - angle)
	return distance_to_zero <= _rotation_snap_tolerance
