extends Control

# ─── Node references ─────────────────────────────────────────────────────────

@onready var _play_button: Button = %PlayButton
@onready var _gallery_button: Button = %GalleryButton
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _settings_button: Button = %SettingsButton
@onready var _resume_button: Button = %ResumeButton

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_gallery_button.pressed.connect(_on_gallery_pressed)
	_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_resume_button.pressed.connect(_on_resume_pressed)

	_refresh_resume_button(GameState.has_save)
	_apply_button_styles()

	for btn: Button in [_play_button, _gallery_button, _leaderboard_button, _settings_button, _resume_button]:
		_add_button_feedback(btn)


# ─── Navigation ──────────────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SceneSelect.tscn")


func _on_gallery_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SceneSelect.tscn")


func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/leaderboard.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")


func _on_resume_pressed() -> void:
	if not _load_saved_puzzle_data():
		_show_error("No saved puzzle found to resume.")
		_refresh_resume_button(false)
		GameState.has_save = false
		return
	GameState.resume_save = true
	get_tree().change_scene_to_file("res://scenes/game/puzzle_scene.tscn")


# ─── Resume helpers ──────────────────────────────────────────────────────────

func _refresh_resume_button(show: bool) -> void:
	_resume_button.visible = show
	_resume_button.disabled = not show


func _load_saved_puzzle_data() -> bool:
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		return false
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var payload := json.get_data() as Dictionary
	if payload == null:
		return false

	var path := payload.get("image_path", "") as String
	var tex: Texture2D = null
	if path != "":
		var img := Image.load_from_file(path)
		if img != null:
			_limit_image_size(img)
			tex = ImageTexture.create_from_image(img)

	if tex == null and GameState.image_texture != null:
		tex = GameState.image_texture

	if tex == null:
		return false

	GameState.image_path = path
	GameState.image_texture = tex
	GameState.gallery_index = int(payload.get("gallery_index", GameState.gallery_index))
	GameState.cols = int(payload.get("cols", GameState.cols))
	GameState.rows = int(payload.get("rows", GameState.rows))
	GameState.piece_shape = payload.get("piece_shape", GameState.piece_shape) as String
	GameState.allow_rotation = bool(payload.get("allow_rotation", GameState.allow_rotation))
	GameState.snap_to_board = bool(payload.get("snap_to_board", GameState.snap_to_board))
	GameState.difficulty_explicitly_set = true
	return true


# ─── Styling ─────────────────────────────────────────────────────────────────

func _apply_button_styles() -> void:
	# PLAY: golden yellow
	_style_pill_button(_play_button, Color(0.88, 0.66, 0.08), Color(1.0, 0.86, 0.28))
	# GALLERY: blue
	_style_pill_button(_gallery_button, Color(0.2, 0.4, 0.76), Color(0.36, 0.6, 0.96))
	# LEADERBOARD: purple
	_style_pill_button(_leaderboard_button, Color(0.44, 0.26, 0.78), Color(0.62, 0.44, 0.96))
	# SETTINGS: green
	_style_pill_button(_settings_button, Color(0.2, 0.58, 0.24), Color(0.3, 0.78, 0.36))
	# RESUME: teal/blue-grey
	_style_pill_button(_resume_button, Color(0.18, 0.38, 0.62), Color(0.28, 0.52, 0.82))


func _style_pill_button(btn: Button, base: Color, highlight: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.corner_radius_top_left = 30
	normal.corner_radius_top_right = 30
	normal.corner_radius_bottom_left = 30
	normal.corner_radius_bottom_right = 30
	normal.shadow_size = 16
	normal.shadow_color = Color(0, 0, 0, 0.38)
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.border_color = highlight

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lightened(0.1)
	hover.border_color = highlight.lightened(0.08)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base.darkened(0.1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))


# ─── Button feedback animations ──────────────────────────────────────────────

func _add_button_feedback(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	btn.mouse_entered.connect(func() -> void:
		_create_feedback_tween(btn, Vector2(1.05, 1.05), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		_create_feedback_tween(btn, Vector2(1, 1), 0.12)
	)
	btn.button_down.connect(func() -> void:
		_create_feedback_tween(btn, Vector2(0.96, 0.96), 0.08)
	)
	btn.button_up.connect(func() -> void:
		_create_feedback_tween(btn, Vector2(1, 1), 0.08)
	)


func _create_feedback_tween(ctrl: Control, target: Vector2, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(ctrl, "scale", target, duration).set_trans(Tween.TRANS_SINE)


# ─── Image utilities ─────────────────────────────────────────────────────────

const _MAX_IMAGE_DIMENSION := 2048

func _limit_image_size(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w <= _MAX_IMAGE_DIMENSION and h <= _MAX_IMAGE_DIMENSION:
		return
	var scale: float = float(_MAX_IMAGE_DIMENSION) / float(maxi(w, h))
	img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_LANCZOS)


# ─── Error dialog ────────────────────────────────────────────────────────────

func _show_error(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Oops"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)

