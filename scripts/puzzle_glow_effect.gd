extends Node2D

## Puzzle Glow Effect
## Draws a pulsing, multi-layered coloured border that expands outward from the
## completed puzzle rectangle.  The glow peaks in brightness at the moment of
## completion then slowly fades over FADE_DURATION seconds.
##
## Usage:
##   var glow = PuzzleGlowEffect.new()
##   add_child(glow)
##   glow.start(Rect2(Vector2.ZERO, puzzle_pixel_size))

## Base colour of the victory glow (soft purple/lavender).
const GLOW_COLOR: Color = Color(0.80, 0.60, 1.0)

## Number of concentric border passes drawn per frame.
## Higher values produce a wider, softer halo at the cost of more draw calls.
const GLOW_LAYERS: int = 4

## Thickness (pixels) of each individual glow layer.
const LAYER_THICKNESS: float = 5.0

## How many radians per second the pulse oscillates.
## Faster pulsing for more dynamic effect.
const PULSE_SPEED: float = 4.0

## Alpha range for the oscillating pulse.
## Wider range for more dramatic pulsing.
const ALPHA_MIN: float = 0.30
const ALPHA_MAX: float = 0.95

## Total seconds the effect runs before fully fading out and stopping.
const FADE_DURATION: float = 6.0

## Internal state.
var _rect: Rect2 = Rect2()
var _time: float = 0.0
var _fade_elapsed: float = 0.0
var _running: bool = false


## Begin the effect around the given pixel-space rectangle.
## Call with the puzzle's local-space bounding rect (e.g. Rect2(0, 0, w, h)).
func start(rect: Rect2) -> void:
	_rect = rect
	_time = 0.0
	_fade_elapsed = 0.0
	_running = true
	set_process(true)
	queue_redraw()


## Immediately halt the effect and clear the drawn glow.
func stop() -> void:
	_running = false
	set_process(false)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_fade_elapsed += delta
	queue_redraw()
	if _fade_elapsed >= FADE_DURATION:
		stop()


func _draw() -> void:
	if not _running:
		return

	# Smooth fade curve using ease-out for more natural tapering.
	var fade_progress: float = _fade_elapsed / FADE_DURATION
	var fade: float = clampf(1.0 - fade_progress * fade_progress, 0.0, 1.0)
	# Dual-frequency pulse: fast oscillation modulated by slower wave for complexity.
	var fast_pulse: float = sin(_time * PULSE_SPEED) * 0.5 + 0.5
	var slow_pulse: float = sin(_time * PULSE_SPEED * 0.3) * 0.3 + 0.7
	var pulse: float = fast_pulse * slow_pulse
	var base_alpha: float = lerp(ALPHA_MIN, ALPHA_MAX, pulse) * fade

	# Draw GLOW_LAYERS concentric outlines, each slightly expanded and dimmer.
	for i: int in range(GLOW_LAYERS):
		var expand: float = float(i) * LAYER_THICKNESS
		var expanded_rect: Rect2 = _rect.grow(expand)
		# Outermost layers are progressively more transparent.
		var alpha: float = base_alpha * (1.0 - float(i) / float(GLOW_LAYERS))
		draw_rect(expanded_rect, Color(GLOW_COLOR, alpha), false, LAYER_THICKNESS)
