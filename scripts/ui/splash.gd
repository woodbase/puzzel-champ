extends Control

@export var next_scene : String = "res://scenes/main_menu.tscn"
@export var splash_time : float = 2.5
@export var fade_time : float = 1.0

@onready var splash_image : TextureRect = $SplashImage

func _ready() -> void:
	# Start the image fully transparent so it fades in from the black background.
	splash_image.modulate.a = 0.0

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
