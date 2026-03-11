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

# ─── Leaderboard ─────────────────────────────────────────────────────────────

## File path where leaderboard scores are persisted between sessions.
const LEADERBOARD_PATH := "user://leaderboard.json"

## Maximum number of scores retained per difficulty level (cols × rows pair).
const LEADERBOARD_MAX_PER_DIFF := 10

## In-memory leaderboard. Each entry is a Dictionary with keys:
##   "time" – elapsed seconds (float, rounded to nearest millisecond)
##   "cols" – puzzle column count (int)
##   "rows" – puzzle row count (int)
##   "date" – ISO-8601 date string, e.g. "2024-06-15" (String)
var _leaderboard: Array = []

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

	_load_leaderboard()


# ─── Leaderboard API ──────────────────────────────────────────────────────────

## Saves a completed-puzzle score and persists the leaderboard to disk.
## Only the best LEADERBOARD_MAX_PER_DIFF scores per difficulty are kept.
func save_score(time: float, p_cols: int, p_rows: int) -> void:
	var entry: Dictionary = {
		"time": snappedf(time, 0.001),
		"cols": p_cols,
		"rows": p_rows,
		"date": Time.get_date_string_from_system(),
	}
	_leaderboard.append(entry)

	# Partition entries for this difficulty and the rest separately.
	var same: Array = []
	var other: Array = []
	for e: Dictionary in _leaderboard:
		if e.get("cols", 0) == p_cols and e.get("rows", 0) == p_rows:
			same.append(e)
		else:
			other.append(e)

	# Keep only the top scores for this difficulty.
	same.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	if same.size() > LEADERBOARD_MAX_PER_DIFF:
		same = same.slice(0, LEADERBOARD_MAX_PER_DIFF)

	_leaderboard = other + same
	_persist_leaderboard()


## Returns a sorted (ascending time) copy of leaderboard entries that match
## the given difficulty.  Returns at most LEADERBOARD_MAX_PER_DIFF entries.
func get_scores_for_difficulty(p_cols: int, p_rows: int) -> Array:
	var result: Array = []
	for e: Dictionary in _leaderboard:
		if e.get("cols", 0) == p_cols and e.get("rows", 0) == p_rows:
			result.append(e)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	return result.slice(0, LEADERBOARD_MAX_PER_DIFF)


## Returns a copy of all leaderboard entries.
func get_all_scores() -> Array:
	return _leaderboard.duplicate()


## Loads the leaderboard from disk.  Silently ignores missing or malformed files.
func _load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		_leaderboard = parsed
	elif parsed is Dictionary and parsed.has("scores"):
		_leaderboard = parsed["scores"]


## Writes the in-memory leaderboard to disk as JSON.
func _persist_leaderboard() -> void:
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: could not open leaderboard file for writing.")
		return
	file.store_string(JSON.stringify(_leaderboard, "\t"))
	file.close()


## Formats elapsed seconds as "M:SS.ss" (minutes:seconds.hundredths),
## or "H:MM:SS.ss" when the time exceeds one hour.
## Used by leaderboard displays across scenes.
static func format_score_time(seconds: float) -> String:
	var total_s: int = int(seconds)
	var h: int = total_s / 3600
	var m: int = (total_s % 3600) / 60
	var s: int = total_s % 60
	var cs: int = int((seconds - float(total_s)) * 100.0)
	if h > 0:
		return "%d:%02d:%02d.%02d" % [h, m, s, cs]
	return "%d:%02d.%02d" % [m, s, cs]
