extends Button

@export var base_color: Color = Color(0.32, 0.42, 0.92)
@export var accent_color: Color = Color(0.74, 0.86, 1.0)
@export var corner_radius: int = 16
@export var size_hint: Vector2 = Vector2(56, 56)

var _hover_tween: Tween = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = size_hint
	_apply_styles()
	_bind_feedback()
	_update_pivot()
	resized.connect(_update_pivot)


func _apply_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = corner_radius
	normal.corner_radius_top_right = corner_radius
	normal.corner_radius_bottom_left = corner_radius
	normal.corner_radius_bottom_right = corner_radius
	normal.shadow_color = Color(0, 0, 0, 0.28)
	normal.shadow_size = 12
	normal.border_color = accent_color
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.10)
	hover.border_color = accent_color.lightened(0.06)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.12)
	pressed.shadow_size = 8

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_color_override("font_color", Color(1, 1, 1))
	add_theme_color_override("font_hover_color", Color(1, 1, 1))
	add_theme_color_override("font_pressed_color", Color(1, 1, 1))


func _bind_feedback() -> void:
	mouse_entered.connect(func() -> void: _animate_scale(Vector2(1.06, 1.06), 0.12))
	mouse_exited.connect(func() -> void: _animate_scale(Vector2.ONE, 0.12))
	button_down.connect(func() -> void: _animate_scale(Vector2(0.95, 0.95), 0.08))
	button_up.connect(func() -> void: _animate_scale(Vector2.ONE, 0.08))


func _animate_scale(target: Vector2, duration: float) -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, duration).set_trans(Tween.TRANS_SINE)


func _update_pivot() -> void:
	pivot_offset = size * 0.5
