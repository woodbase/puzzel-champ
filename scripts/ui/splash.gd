extends Control

@export var next_scene : String = "res://scenes/main_menu.tscn"
@export var splash_time : float = 2.5
@export var fade_time : float = 1.0

@onready var splash_image : TextureRect = $SplashImage

## Starting colour for the title shimmer (accent-purple, fully transparent).
const TITLE_COLOR_START := Color(0.75, 0.45, 1.0, 0.0)
## Ending colour for the title shimmer (neutral near-white, fully opaque).
const TITLE_COLOR_END   := Color(0.88, 0.82, 0.98, 1.0)
## Colour of the subtitle label.
const SUBTITLE_COLOR    := Color(0.65, 0.55, 0.85)

func _ready():

	# Start image transparent; the black Background node stays fully opaque
	# so the sequence is genuinely "fade in from black, fade out to black"
	splash_image.modulate.a = 0.0

	# ── Prototype: Logo / splash animation ─────────────────────────────────────
	# A branded title and tagline animate in on the dark background before the
	# splash image reveals itself, giving the intro a polished "logo build-up"
	# feel.  All elements then fade out in unison before the scene changes.

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "PUZZLE CHAMP"
	title_lbl.add_theme_font_size_override("font_size", 64)
	title_lbl.add_theme_color_override("font_color", TITLE_COLOR_END)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate.a = 0.0
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Assemble your world"
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", SUBTITLE_COLOR)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.modulate.a = 0.0
	vbox.add_child(sub_lbl)

	var tween = create_tween()

	# Title fades in with a brief colour shimmer from accent-purple to white.
	tween.tween_property(title_lbl, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(
		title_lbl, "modulate",
		TITLE_COLOR_END, 0.6
	).from(TITLE_COLOR_START)

	# Subtitle fades in right after the title is fully visible.
	tween.tween_property(sub_lbl, "modulate:a", 1.0, 0.4)

	# Splash image fades in over the text.
	tween.tween_property(splash_image, "modulate:a", 1.0, fade_time)

	# Hold.
	tween.tween_interval(splash_time)

	# All elements fade out together.
	tween.tween_property(splash_image, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(title_lbl, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(sub_lbl, "modulate:a", 0.0, fade_time)

	# Load next scene.
	tween.tween_callback(load_next_scene)


func load_next_scene():
	var err = get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("Splash: failed to load scene '%s' (error %d)" % [next_scene, err])
