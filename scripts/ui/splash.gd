extends Control

@export var next_scene : String = "res://scenes/ui/MainMenu.tscn"
@export var splash_time : float = 2.5
@export var fade_time : float = 1.0
@export var portrait_texture : Texture2D
@export var landscape_texture : Texture2D

@onready var splash_image : TextureRect = $SplashImage

func _ready() -> void:
	# Start the image fully transparent so it fades in from the black background.
	splash_image.modulate.a = 0.0
	UIScale.layout_changed.connect(_on_layout_changed)
	_update_splash_texture()

	var tween := create_tween()

	# Fade in the branded splash image.
	tween.tween_property(splash_image, "modulate:a", 1.0, fade_time)

	# Hold on the splash image.
	tween.tween_interval(splash_time)

	# Fade back to black, then load the main menu.
	tween.tween_property(splash_image, "modulate:a", 0.0, fade_time)
	tween.tween_callback(load_next_scene)


func load_next_scene() -> void:
	var err := get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("Splash: failed to load scene '%s' (error %d)" % [next_scene, err])


func _on_layout_changed() -> void:
	_update_splash_texture()


func _update_splash_texture() -> void:
	if portrait_texture == null:
		portrait_texture = splash_image.texture
	var vp := get_viewport().get_visible_rect().size
	var want_landscape := vp.x >= vp.y
	var target := landscape_texture if want_landscape and landscape_texture != null else portrait_texture
	if target != null and splash_image.texture != target:
		splash_image.texture = target
	splash_image.stretch_mode = TextureRect.STRETCH_SCALE
