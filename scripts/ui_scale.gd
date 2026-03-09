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
