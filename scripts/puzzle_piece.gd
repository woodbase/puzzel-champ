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

## Whether the player has pressed this piece but not yet exceeded the drag threshold.
var _pending_drag: bool = false

## The global position where the press started, used to measure drag distance.
var _press_start: Vector2 = Vector2.ZERO

## Minimum pixel movement required before a press is recognised as a drag.
## Prevents accidental piece movement when tapping.
const DRAG_THRESHOLD: float = 10.0

## Offset between the piece's position and the mouse when drag starts.
var _drag_offset: Vector2 = Vector2.ZERO

## Touch finger index currently driving this piece (-1 = mouse / not set).
## Used to ensure only the originating finger controls the drag; other fingers
## are ignored so multi-touch gestures don't cause erratic piece movement.
var _drag_touch_index: int = -1

## z_index captured at drag start, restored on drop.
var _original_z_index: int = 0

## Elevated z_index while dragging so the piece renders on top.
const DRAG_Z_INDEX: int = 10

## Scale multiplier applied to the piece's sprite when it is picked up.
## The same factor is reversed in cancel_drag() and _end_drag() to keep
## the scale animations symmetric.
const DRAG_SCALE_FACTOR: float = 1.08

## Distance threshold in pixels for snapping to the correct position.
## Set by PuzzleBoard after instantiation so the threshold scales with the
## actual piece size rather than using a fixed pixel value.
var snap_distance: float = 40.0

## Buffer seconds added after particle lifetime before the node is freed.
const PARTICLE_CLEANUP_DELAY: float = 0.2

## Golden colour used for the lock-particle burst.
const PARTICLE_COLOR: Color = Color(1.0, 0.9, 0.3)

## Current rotation step (0–3) when piece rotation is enabled.
## 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°. A piece can only snap when
## rotation_steps == 0 (correct orientation).
var rotation_steps: int = 0


func _ready() -> void:
	input_pickable = true


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_locked:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Record press position; actual drag begins only after DRAG_THRESHOLD
			# is exceeded, preventing accidental moves when tapping.
			_press_start = get_global_mouse_position()
			_pending_drag = true
			# Consume the event so overlapping pieces don't also start dragging,
			# which could cause the wrong piece to snap into an incorrect position.
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed \
				and GameState.allow_rotation:
			_rotate_clockwise()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		# Explicit touch handling for mobile devices.  Even when
		# emulate_mouse_from_touch is on both the ScreenTouch and the
		# synthesised MouseButton will fire; _start_drag guards against
		# double-invocation so only the first call takes effect.
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			# Record press position and which finger owns this drag so that
			# subsequent drag events from other fingers are ignored.
			_press_start = touch_event.position
			_drag_touch_index = touch_event.index
			_pending_drag = true
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging and not _pending_drag:
		return

	if event is InputEventMouseMotion:
		if _pending_drag and not _dragging:
			# Start dragging once the cursor has moved far enough from the press
			# position, so brief taps don't accidentally move pieces.
			if get_global_mouse_position().distance_to(_press_start) >= DRAG_THRESHOLD:
				_start_drag(get_global_mouse_position())
		elif _dragging:
			_update_drag(get_global_mouse_position())

	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		# Ignore drag events from a different finger than the one that started
		# this drag.  This prevents erratic movement when a second finger touches
		# the screen while a piece is already being dragged.
		if _drag_touch_index != -1 and screen_drag.index != _drag_touch_index:
			return
		var drag_pos: Vector2 = screen_drag.position
		if _pending_drag and not _dragging:
			if drag_pos.distance_to(_press_start) >= DRAG_THRESHOLD:
				_start_drag(drag_pos)
		elif _dragging:
			# Keep the piece following the finger while it moves.
			_update_drag(drag_pos)

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_pending_drag = false
			if _dragging:
				_end_drag()

	elif event is InputEventScreenTouch:
		# Finger lifted – end the drag.  _end_drag guards against the
		# matching MouseButton release that emulate_mouse_from_touch also fires.
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed and touch_event.index == _drag_touch_index:
			_drag_touch_index = -1
			_pending_drag = false
			if _dragging:
				_end_drag()


## Begins dragging the piece.
## Enhanced with scale-up animation for visual feedback.
func _start_drag(mouse_pos: Vector2) -> void:
	if _dragging:
		return  # Guard: ignore if already dragging (e.g. touch + emulated mouse).
	_dragging = true
	_drag_offset = global_position - mouse_pos
	_original_z_index = z_index
	z_index = DRAG_Z_INDEX

	# Smooth scale-up animation when picking up the piece.
	if GameState.feedback_visual:
		var sprite := get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			var base_scale := sprite.scale
			var tween := create_tween()
			tween.tween_property(sprite, "scale", base_scale * DRAG_SCALE_FACTOR, 0.12) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	piece_picked_up.emit()


## Moves the piece to follow the mouse.
func _update_drag(mouse_pos: Vector2) -> void:
	global_position = mouse_pos + _drag_offset


## Cancels an in-progress drag without attempting to snap the piece.
## Called by PuzzleBoard when a multi-touch gesture begins so the piece
## returns to its pre-drag z_index and the drag state is fully cleared.
func cancel_drag() -> void:
	if not _dragging and not _pending_drag:
		return
	_pending_drag = false
	_drag_touch_index = -1
	if _dragging:
		_dragging = false
		z_index = _original_z_index
		# Restore the sprite scale that was animated up at drag start.
		if GameState.feedback_visual:
			var sprite := get_node_or_null("Sprite2D") as Sprite2D
			if sprite != null:
				var base_scale := sprite.scale / DRAG_SCALE_FACTOR
				var tween := create_tween()
				tween.tween_property(sprite, "scale", base_scale, 0.12) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		piece_released.emit()


## Rotates the piece 90° clockwise and increments the rotation_steps counter.
## Only called when GameState.allow_rotation is enabled.
func _rotate_clockwise() -> void:
	rotation_steps = (rotation_steps + 1) % 4
	rotation_degrees = rotation_steps * 90.0


## Ends dragging; snaps and locks the piece if close enough to its target.
## Enhanced with scale-down animation when releasing.
## When allow_rotation is enabled the piece must also be in the correct
## orientation (rotation_steps == 0) before it can snap into place.
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
	var rotation_correct: bool = (rotation_steps == 0) or not GameState.allow_rotation
	if distance < snap_distance and rotation_correct:
		# Always snap to the exact target so no visible offset remains.
		# GameState.snap_to_board controls only the pre-snap highlight drawn
		# by PuzzleBoard._draw(); the final position is always corrected here.
		global_position = correct_global
		rotation_degrees = 0.0
		is_locked = true
		input_pickable = false
		if GameState.feedback_haptic:
			Input.vibrate_handheld(50)
		if GameState.feedback_visual:
			_play_snap_animation()
			_spawn_lock_particles()
		piece_placed.emit()
	else:
		# Piece not snapped - scale back to normal smoothly.
		if GameState.feedback_visual:
			var sprite := get_node_or_null("Sprite2D") as Sprite2D
			if sprite != null:
				var base_scale := sprite.scale / DRAG_SCALE_FACTOR  # Undo the pickup scale.
				var tween := create_tween()
				tween.tween_property(sprite, "scale", base_scale, 0.15) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	piece_released.emit()


## Spawns a brief, subtle burst of golden particles at the locked position.
## Enhanced with more particles, varied velocities, and scale animation.
func _spawn_lock_particles() -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)

	# Use fewer, simpler particles on mobile to reduce GPU and CPU pressure.
	var is_mobile: bool = GameState.is_mobile
	# Burst of golden dots – one-shot, fully simultaneous.
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8 if is_mobile else 18
	particles.lifetime = 0.7

	# Emit from a small area around the piece centre.
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0

	# Scatter upward and outward with wider spread and more varied velocity.
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.gravity = Vector2(0.0, 80.0)

	# Fade out over the particle lifetime via a colour gradient.
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(PARTICLE_COLOR.r, PARTICLE_COLOR.g, PARTICLE_COLOR.b, 1.0))
	color_ramp.set_color(1, Color(PARTICLE_COLOR.r, PARTICLE_COLOR.g, PARTICLE_COLOR.b, 0.0))
	particles.color_ramp = color_ramp

	# Vary particle sizes more for visual interest.
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0

	# Add scale curve for particles to shrink as they fade (skip on mobile to
	# avoid per-frame curve evaluation overhead).
	if not is_mobile:
		var scale_curve := Curve.new()
		scale_curve.add_point(Vector2(0.0, 1.0))
		scale_curve.add_point(Vector2(0.7, 0.8))
		scale_curve.add_point(Vector2(1.0, 0.3))
		particles.scale_amount_curve = scale_curve

	# Start emitting, then clean up after the burst finishes.
	particles.emitting = true
	var timer := get_tree().create_timer(particles.lifetime + PARTICLE_CLEANUP_DELAY)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Plays a brief scale-bounce and colour-flash animation on the sprite.
## Squash → expand → elastic bounce back to natural 1× scale with a gold flash.
## The sprite may be at drag scale (DRAG_SCALE_FACTOR) when this is called, so
## all phases target absolute values relative to Vector2.ONE so the locked piece
## always settles at its natural size.
func _play_snap_animation() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var tween := create_tween()
	# Phase 0: Quick anticipation squash (0.05 s) for snappier feel.
	tween.tween_property(sprite, "scale", Vector2(0.92, 0.92), 0.05) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Phase 1: Pop up and flash to gold (0.12 s), both properties in parallel.
	tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.12) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(sprite, "modulate", Color(1.6, 1.4, 0.2, 1.0), 0.12)
	# Phase 2: Elastic spring back to natural scale (0.22 s) with stronger overshoot
	# for a more satisfying snap feel; colour fade runs in parallel.
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
