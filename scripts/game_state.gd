extends Node

## True when the game is running on a mobile device (Android or iOS).
## Detected once at startup; read-only after _ready().
var is_mobile: bool = false

## Physical screen size in pixels as reported by the display server at startup.
var screen_size: Vector2i = Vector2i.ZERO

## Path to the selected image file.
## For built-in gallery images this is the res:// resource path.
## For user-uploaded images this is the user:// path where the copy was saved.
## Empty string means no path is stored.
var image_path: String = ""

## Pre-loaded texture for the puzzle.
## Non-null when an image has been selected from the gallery or uploaded.
var image_texture: Texture2D = null

## Index of the selected gallery item (-1 = selection outside the current gallery).
## Indices 0..N-1 map to the bundled default images; higher indices are
## user-uploaded images loaded from user://gallery/.
var gallery_index: int = 0

## Number of puzzle columns.
var cols: int = 4

## Number of puzzle rows.
var rows: int = 3

## Selected piece shape. Possible values: "square", "jigsaw".
var piece_shape: String = "jigsaw"

## Whether visual snap feedback (scale bounce + colour flash) is enabled.
var feedback_visual: bool = true

## Whether audio snap feedback (sound effect) is enabled.
var feedback_audio: bool = true

## Whether haptic snap feedback (device vibration) is enabled.
var feedback_haptic: bool = true

## Whether background music is enabled during gameplay.
var music_enabled: bool = true

## Master volume for all game audio (linear scale: 0.0 = silent, 1.0 = full).
var volume: float = 1.0

## True once the player has explicitly started a game (difficulty has been
## committed at least once). Used by the main menu to decide whether to
## auto-select a screen-size-appropriate difficulty on first load.
var difficulty_explicitly_set: bool = false

func _ready() -> void:
	# ── Device-type detection ────────────────────────────────────────────────
	# OS.has_feature("mobile") is Godot's canonical check for Android and iOS.
	# It is evaluated before any scene loads, satisfying the startup-detection
	# requirement and giving all other autoloads and scenes a stable value to
	# read from GameState.is_mobile.
	is_mobile = OS.has_feature("mobile")

	# Record the physical screen size at startup so that layout code (e.g.
	# UIScale, main_menu) can reference it without repeating the query.
	screen_size = DisplayServer.screen_get_size()

	# ── Difficulty defaults based on device type ─────────────────────────────
	# On mobile, start with Easy (3×2) so pieces are large enough for touch.
	# On desktop the existing Medium default (4×3) is already appropriate.
	if is_mobile:
		cols = 3
		rows = 2
