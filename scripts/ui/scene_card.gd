extends Button

signal scene_selected(texture: Texture2D, path: String, index: int)

@export var scene_texture: Texture2D:
	set(value):
		scene_texture = value
		if is_instance_valid(_texture_rect):
			_texture_rect.texture = value

@export var scene_path: String = ""
@export var scene_index: int = -1

@onready var _texture_rect: TextureRect = $TextureRect

var _hover_tween: Tween = null

func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_texture_rect.texture = scene_texture

	pressed.connect(_on_pressed)
	toggled.connect(func(_on: bool) -> void: _refresh_style())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(func() -> void: _animate_scale(0.96, 0.08))
	button_up.connect(func() -> void: _animate_scale(1.0, 0.08))
	resized.connect(_update_pivot)

	_update_pivot()
	_refresh_style()


func set_selected(active: bool) -> void:
	button_pressed = active
	_refresh_style()


func _on_pressed() -> void:
	scene_selected.emit(scene_texture, scene_path, scene_index)
	_refresh_style()


func _refresh_style() -> void:
	var accent := get_theme_color("accent_color", "Button")
	var base := get_theme_stylebox("normal", "Button") as StyleBoxFlat

	var sb := StyleBoxFlat.new()
	if base != null:
		sb.bg_color = base.bg_color
		sb.corner_radius_top_left = base.corner_radius_top_left
		sb.corner_radius_top_right = base.corner_radius_top_right
		sb.corner_radius_bottom_left = base.corner_radius_bottom_left
		sb.corner_radius_bottom_right = base.corner_radius_bottom_right
		sb.shadow_color = base.shadow_color
		sb.shadow_size = base.shadow_size
	else:
		sb.bg_color = Color(0.98, 0.96, 0.94)
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.shadow_color = Color(0, 0, 0, 0.08)
		sb.shadow_size = 6

	if button_pressed:
		sb.border_color = accent
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.bg_color = sb.bg_color.lightened(0.05)
	else:
		sb.border_color = Color(0.9, 0.82, 0.74)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1

	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)


func _on_mouse_entered() -> void:
	_animate_scale(1.05, 0.12)


func _on_mouse_exited() -> void:
	_animate_scale(1.0, 0.12)


func _animate_scale(target: float, duration: float) -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(target, target), duration).set_trans(Tween.TRANS_SINE)


func _update_pivot() -> void:
	pivot_offset = size * 0.5
