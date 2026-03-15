extends Node

## Reference resolution for scale-factor calculations.
## UI elements designed at this resolution will appear at 1× on screens of the
## same physical size; smaller screens shrink them (down to 0.5×) and larger
## screens enlarge them (up to 2×).
const BASE_WIDTH: float  = 1280.0
const BASE_HEIGHT: float = 720.0

## Emitted whenever the viewport changes size (orientation flip, window resize).
## Listeners should connect here instead of connecting directly to
## get_viewport().size_changed so that the scale factor is already updated
## when the signal fires.
signal layout_changed

## Cached scale factor – recomputed on every viewport size change.
var _scale_factor: float = 1.0

## Cached portrait flag – true when the viewport is taller than wide.
var _portrait: bool = false

## Cached safe area insets in viewport pixels – recomputed on every viewport
## size change.  Non-zero only on devices that report a safe area (notch,
## status bar, system gesture strip, rounded corners, etc.).
var _safe_top:    float = 0.0
var _safe_bottom: float = 0.0
var _safe_left:   float = 0.0
var _safe_right:  float = 0.0


func _ready() -> void:
	# Defer the first refresh until the viewport is fully initialised.
	call_deferred("_init_viewport")


func _init_viewport() -> void:
	get_viewport().size_changed.connect(_on_size_changed)
	_refresh()


func _on_size_changed() -> void:
	_refresh()
	layout_changed.emit()


func _refresh() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var sx := vp.x / BASE_WIDTH
	var sy := vp.y / BASE_HEIGHT
	_scale_factor = clampf(minf(sx, sy), 0.5, 2.0)
	_portrait = vp.y > vp.x

	# Compute safe area insets in viewport pixels.
	# DisplayServer.get_display_safe_area() returns a Rect2i in *screen* pixels.
	# We scale it to viewport pixels using the screen→viewport ratio so all
	# callers can work in the same coordinate space as the rest of the UI.
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x > 0.0 and screen.y > 0.0:
		var safe := DisplayServer.get_display_safe_area()
		var ratio_x := vp.x / screen.x
		var ratio_y := vp.y / screen.y
		_safe_top    = safe.position.y                          * ratio_y
		_safe_left   = safe.position.x                          * ratio_x
		_safe_bottom = (screen.y - safe.position.y - safe.size.y) * ratio_y
		_safe_right  = (screen.x - safe.position.x - safe.size.x) * ratio_x
	else:
		_safe_top    = 0.0
		_safe_bottom = 0.0
		_safe_left   = 0.0
		_safe_right  = 0.0


## Returns the current UI scale factor (1.0 on the reference 1280×720 resolution).
func scale_factor() -> float:
	return _scale_factor


## Returns true when the viewport is taller than wide (portrait / mobile orientation).
func is_portrait() -> bool:
	return _portrait


## Returns true on a mobile-like form factor – either portrait orientation or a
## viewport narrower than 960 px (small tablet or phone in landscape).
func is_mobile() -> bool:
	var vp := get_viewport().get_visible_rect().size
	return vp.y > vp.x or vp.x < 960.0


## Returns *base* pixels scaled by the current scale factor (rounded to integer).
## Use for margins, separations, minimum sizes, and other pixel measurements.
func px(base: float) -> int:
	return roundi(base * _scale_factor)


## Returns *base_pt* scaled by the current scale factor (rounded to integer).
## Use wherever a font_size theme override is set.
func font_size(base_pt: int) -> int:
	return roundi(float(base_pt) * _scale_factor)


## Returns the safe area insets in viewport pixels.
## The safe area is the region of the screen not obscured by a notch, rounded
## corner, status bar, or system gesture strip.  Insets are the distances from
## each screen edge to the nearest safe boundary.
## Returns a Dictionary with float keys "top", "bottom", "left", "right".
func safe_area_insets() -> Dictionary:
	return {
		"top":    _safe_top,
		"bottom": _safe_bottom,
		"left":   _safe_left,
		"right":  _safe_right,
	}
