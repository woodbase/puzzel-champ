extends Control

## Emitted when the player drops this piece close enough to its correct position.
signal piece_placed

## Emitted when the player starts dragging this piece.
signal piece_picked_up

var grid_position: Vector2i = Vector2i.ZERO
var correct_position: Vector2 = Vector2.ZERO

## Whether this piece has been snapped into its correct position and locked.
var is_locked: bool = false

## Buffer seconds added after particle lifetime before the node is freed.
const PARTICLE_CLEANUP_DELAY: float = 0.2

## Golden colour used for the lock-particle burst.
const PARTICLE_COLOR: Color = Color(1.0, 0.9, 0.3)

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
	if is_locked:
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
				piece_picked_up.emit()
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
		is_locked = true
		# Allow clicks to pass through to unplaced pieces underneath.
		mouse_filter = MOUSE_FILTER_IGNORE
		if feedback_haptic:
			Input.vibrate_handheld(50)
		if feedback_visual:
			_play_snap_animation()
			_spawn_lock_particles()
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


## Spawns a brief, subtle burst of golden particles at the locked position.
## Particles are added to the scene root so they render correctly regardless of
## where this Control node sits in the scene tree.
func _spawn_lock_particles() -> void:
	var particles := CPUParticles2D.new()
	get_tree().root.add_child(particles)

	# Position the burst at the centre of this piece in screen space.
	particles.global_position = get_global_rect().get_center()

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
