extends Node2D

## A simple confetti celebration effect.
## Instantiate this node, call start(), and it will animate colourful confetti
## particles falling across the screen for several seconds.

## Palette of festive colours used for confetti pieces.
const COLOURS: Array = [
	Color(1.00, 0.84, 0.00),  # gold
	Color(0.98, 0.30, 0.30),  # red
	Color(0.25, 0.80, 0.40),  # green
	Color(0.30, 0.60, 1.00),  # blue
	Color(0.90, 0.40, 0.90),  # purple
	Color(1.00, 0.60, 0.10),  # orange
	Color(0.20, 0.90, 0.90),  # cyan
]

## How long (seconds) new particles are spawned after start() is called.
const SPAWN_DURATION: float = 4.0

## Particles spawned per second during the spawn window.
## Increased for more festive effect.
const SPAWN_RATE: float = 70.0

## Downward acceleration applied to every particle (pixels/s²).
const GRAVITY: float = 280.0

## Per-frame horizontal drag coefficient (applied once per frame).
## Assumes ~60 fps; for a visual effect this approximation is acceptable.
const DRAG: float = 0.98

## Extra pixels below the bottom edge before a particle is culled.
const CULL_BUFFER: float = 80.0


## Internal representation of one confetti piece.
class Particle:
	var pos:         Vector2
	var vel:         Vector2
	var angle:       float
	var spin:        float
	var color_index: int  ## Index into COLOURS; avoids per-draw colour lookups.
	var w:           float
	var h:           float


var _particles: Array = []
var _spawn_timer: float = 0.0
var _spawn_accum: float = 0.0
var _screen_size: Vector2 = Vector2(1152.0, 648.0)


## Begin the effect.  Call with the current viewport size.
func start(screen_size: Vector2) -> void:
	_screen_size = screen_size
	_spawn_timer = 0.0
	_spawn_accum = 0.0
	_particles.clear()
	set_process(true)


## Immediately halt the effect and clear all particles.
func stop() -> void:
	_particles.clear()
	set_process(false)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	# Spawn new particles while within the spawn window.
	if _spawn_timer < SPAWN_DURATION:
		_spawn_timer += delta
		_spawn_accum += SPAWN_RATE * delta
		while _spawn_accum >= 1.0:
			_spawn_particle()
			_spawn_accum -= 1.0

	# Integrate and cull existing particles.
	var i: int = _particles.size() - 1
	while i >= 0:
		var p: Particle = _particles[i]
		p.vel.y += GRAVITY * delta
		p.vel.x *= DRAG
		p.pos   += p.vel * delta
		p.angle += p.spin * delta
		if p.pos.y > _screen_size.y + CULL_BUFFER:
			_particles.remove_at(i)
		i -= 1

	queue_redraw()

	# Once spawning stops and all particles have fallen off-screen, idle.
	if _spawn_timer >= SPAWN_DURATION and _particles.is_empty():
		set_process(false)


func _spawn_particle() -> void:
	var p := Particle.new()
	# Spawn across full width with varied starting heights for depth.
	p.pos         = Vector2(randf() * _screen_size.x, randf_range(-60.0, -10.0))
	# More varied velocities for dynamic motion.
	p.vel         = Vector2(randf_range(-70.0, 70.0), randf_range(80.0, 220.0))
	p.angle       = randf() * TAU
	# Faster spin rates for more energy.
	p.spin        = randf_range(-8.0, 8.0)
	p.color_index = randi() % COLOURS.size()
	# Varied sizes for visual interest.
	p.w           = randf_range(6.0, 16.0)
	p.h           = randf_range(3.5, 9.0)
	_particles.append(p)


func _draw() -> void:
	if _particles.is_empty():
		return

	# Build one triangle array covering all active particles.
	# RenderingServer.canvas_item_add_triangle_array submits every particle
	# in a single GPU draw call, regardless of colour or count.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for p: Particle in _particles:
		var cos_a: float = cos(p.angle)
		var sin_a: float = sin(p.angle)
		var hw: float = p.w * 0.5
		var hh: float = p.h * 0.5
		# Rotate the four rectangle corners about the particle centre and
		# translate to world-space – no draw_set_transform call needed.
		var v0 := p.pos + Vector2(-hw * cos_a + hh * sin_a, -hw * sin_a - hh * cos_a)
		var v1 := p.pos + Vector2( hw * cos_a + hh * sin_a,  hw * sin_a - hh * cos_a)
		var v2 := p.pos + Vector2( hw * cos_a - hh * sin_a,  hw * sin_a + hh * cos_a)
		var v3 := p.pos + Vector2(-hw * cos_a - hh * sin_a, -hw * sin_a + hh * cos_a)
		var base: int = points.size()
		points.append(v0)
		points.append(v1)
		points.append(v2)
		points.append(v3)
		var c: Color = COLOURS[p.color_index]
		colors.append(c)
		colors.append(c)
		colors.append(c)
		colors.append(c)
		# Two triangles forming the quad: (v0, v1, v2) and (v0, v2, v3).
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)

	# Submit all particles in a single GPU draw call.
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), indices, points, colors
	)
