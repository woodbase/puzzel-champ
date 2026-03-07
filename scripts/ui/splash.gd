extends Control

@export var next_scene : String = "res://scenes/main_menu.tscn"
@export var splash_time : float = 2.5
@export var fade_time : float = 1.0

@onready var splash_image : TextureRect = $SplashImage

func _ready():

	# Start image transparent; the black Background node stays fully opaque
	# so the sequence is genuinely "fade in from black, fade out to black"
	splash_image.modulate.a = 0.0

	var tween = create_tween()

	# Fade in
	tween.tween_property(splash_image, "modulate:a", 1.0, fade_time)

	# Wait while visible
	tween.tween_interval(splash_time)

	# Fade out
	tween.tween_property(splash_image, "modulate:a", 0.0, fade_time)

	# Load next scene
	tween.tween_callback(load_next_scene)


func load_next_scene():
	var err = get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("Splash: failed to load scene '%s' (error %d)" % [next_scene, err])
