extends Area2D

## Emitted when this piece snaps into its correct position.
signal piece_placed

## Emitted when the player starts dragging this piece.
signal piece_picked_up

## Emitted when the player releases this piece (whether or not it snapped).
signal piece_released

## The correct grid position this piece must snap to.
@export var correct_position: Vector2 = Vector2.ZERO

## Whether this piece has been snapped into its correct position.
var is_locked: bool = false

## Whether this piece is currently being dragged.
var _dragging: bool = false

## Offset between the piece's position and the mouse when drag starts.
var _drag_offset: Vector2 = Vector2.ZERO

## z_index captured at drag start, restored on drop.
var _original_z_index: int = 0

## Elevated z_index while dragging so the piece renders on top.
const DRAG_Z_INDEX: int = 10

## Distance threshold in pixels for snapping to the correct position.
## Set by PuzzleBoard after instantiation so the threshold scales with the
## actual piece size rather than using a fixed pixel value.
var snap_distance: float = 40.0

## Buffer seconds added after particle lifetime before the node is freed.
const PARTICLE_CLEANUP_DELAY: float = 0.2

## Golden colour used for the lock-particle burst.
const PARTICLE_COLOR: Color = Color(1.0, 0.9, 0.3)


func _ready() -> void:
	input_pickable = true


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_locked:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_start_drag(get_global_mouse_position())
			# Consume the event so overlapping pieces don't also start dragging,
			# which could cause the wrong piece to snap into an incorrect position.
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		# Explicit touch handling for mobile devices.  Even when
		# emulate_mouse_from_touch is on both the ScreenTouch and the
		# synthesised MouseButton will fire; _start_drag guards against
		# double-invocation so only the first call takes effect.
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_start_drag(touch_event.position)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		_update_drag(get_global_mouse_position())

	elif event is InputEventScreenDrag:
		# Keep the piece following the finger while it moves.
		_update_drag((event as InputEventScreenDrag).position)

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_end_drag()

	elif event is InputEventScreenTouch:
		# Finger lifted – end the drag.  _end_drag guards against the
		# matching MouseButton release that emulate_mouse_from_touch also fires.
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			_end_drag()


## Begins dragging the piece.
func _start_drag(mouse_pos: Vector2) -> void:
	if _dragging:
		return  # Guard: ignore if already dragging (e.g. touch + emulated mouse).
	_dragging = true
	_drag_offset = global_position - mouse_pos
	_original_z_index = z_index
	z_index = DRAG_Z_INDEX
	piece_picked_up.emit()


## Moves the piece to follow the mouse.
func _update_drag(mouse_pos: Vector2) -> void:
	global_position = mouse_pos + _drag_offset


## Ends dragging; snaps and locks the piece if close enough to its target.
func _end_drag() -> void:
	if not _dragging:
		return  # Guard: ignore if not dragging (e.g. both ScreenTouch + emulated MouseButton fire).
	_dragging = false
	z_index = _original_z_index

	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		push_error("Puzzle piece parent must be a Node2D to compute correct_global position.")
		piece_released.emit()
		return

	var correct_global: Vector2 = parent_2d.to_global(correct_position)
	var distance := global_position.distance_to(correct_global)
	if distance < snap_distance:
		global_position = correct_global
		is_locked = true
		input_pickable = false
		if GameState.feedback_haptic:
			Input.vibrate_handheld(50)
		if GameState.feedback_visual:
			_play_snap_animation()
			_spawn_lock_particles()
		piece_placed.emit()
	piece_released.emit()


## Spawns a brief, subtle burst of golden particles at the locked position.
func _spawn_lock_particles() -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)

	# Burst of 12 small golden dots – one-shot, fully simultaneous.
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.6

	# Emit from a small area around the piece centre.
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0

	# Scatter upward with a wide spread and slight gravity.
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.gravity = Vector2(0.0, 60.0)

	# Fade out over the particle lifetime via a colour gradient.
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(PARTICLE_COLOR.r, PARTICLE_COLOR.g, PARTICLE_COLOR.b, 1.0))
	color_ramp.set_color(1, Color(PARTICLE_COLOR.r, PARTICLE_COLOR.g, PARTICLE_COLOR.b, 0.0))
	particles.color_ramp = color_ramp

	# Small square dots.
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	# Start emitting, then clean up after the burst finishes.
	particles.emitting = true
	var timer := get_tree().create_timer(particles.lifetime + PARTICLE_CLEANUP_DELAY)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Plays a brief scale-bounce and colour-flash animation on the sprite.
func _play_snap_animation() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var base_scale: Vector2 = sprite.scale
	var tween := create_tween()
	# Phase 1: scale up and flash to gold (0.10 s), both properties in parallel.
	tween.tween_property(sprite, "scale", base_scale * 1.22, 0.10)
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 1.3, 0.3, 1.0), 0.10)
	# Phase 2: spring back to normal (0.20 s) with an elastic overshoot for a
	# satisfying snap feel; colour fade runs in parallel.
	tween.tween_property(sprite, "scale", base_scale, 0.20) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.20)
