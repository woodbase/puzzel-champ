extends Control

# Difficulty presets exposed for puzzle_board and other scenes.
const DIFFICULTIES: Array[Dictionary] = [
	{"key": "easy",   "label": "Easy",   "cols": 3, "rows": 2},
	{"key": "medium", "label": "Medium", "cols": 4, "rows": 3},
	{"key": "hard",   "label": "Hard",   "cols": 6, "rows": 4},
	{"key": "expert", "label": "Expert", "cols": 8, "rows": 6},
]

const SHAPES: Array[Dictionary] = [
	{"key": "square", "label": "Square"},
	{"key": "jigsaw", "label": "Jigsaw"},
]

const DEFAULT_IMAGE_PATHS: Array[String] = [
	"res://gfx/puzzles/pexels-harun-tan-2311991-3980364.jpg",
	"res://gfx/puzzles/pexels-pixabay-206768.jpg",
	"res://gfx/puzzles/pexels-pixabay-268533.jpg",
	"res://gfx/puzzles/pexels-robshumski-1903702.jpg",
	"res://gfx/puzzles/pexels-connorscottmcmanus-28368352.jpg",
]

const USER_GALLERY_DIR := "user://gallery/"
const MAX_IMAGE_DIMENSION := 2048

const SceneCardScene := preload("res://scenes/ui/scene_card.tscn")

var selected_scene: Texture2D = null
var selected_path: String = ""
var selected_index: int = -1
var difficulty: String = "medium"
var shape: String = "jigsaw"

var _gallery_textures: Array[Texture2D] = []
var _gallery_paths: Array[String] = []
var _scene_cards: Array[Button] = []
var _scene_group := ButtonGroup.new()

@onready var _content: VBoxContainer = %Content
@onready var _scene_grid: GridContainer = %SceneGrid
@onready var _upload_button: Button = %UploadButton
@onready var _upload_dialog: FileDialog = $UploadDialog
@onready var _start_button: Button = %StartButton
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _settings_button: Button = %SettingsButton
@onready var _resume_button: Button = %ResumeButton
@onready var _rotation_toggle: CheckButton = %RotationToggle
@onready var _snap_toggle: CheckButton = %SnapToggle

@onready var _difficulty_buttons: Dictionary = {
	"easy": %EasyButton,
	"medium": %MediumButton,
	"hard": %HardButton,
	"expert": %ExpertButton,
}

@onready var _shape_buttons: Dictionary = {
	"square": %SquareButton,
	"jigsaw": %JigsawButton,
}


func _ready() -> void:
	_upload_button.pressed.connect(_on_upload_pressed)
	_upload_dialog.file_selected.connect(_on_file_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	if _resume_button != null:
		_resume_button.pressed.connect(_on_resume_pressed)
	if _rotation_toggle != null:
		_rotation_toggle.toggled.connect(func(pressed: bool) -> void:
			GameState.allow_rotation = pressed
		)
	if _snap_toggle != null:
		_snap_toggle.toggled.connect(func(pressed: bool) -> void:
			GameState.snap_to_board = pressed
		)
	UIScale.layout_changed.connect(_apply_responsive_layout)

	_load_gallery()
	_build_scene_cards()
	_init_difficulty_buttons()
	_init_shape_buttons()
	_restore_previous_selection()
	_apply_responsive_layout()
	_refresh_resume_button(GameState.has_save)

	_add_button_feedback(_upload_button)
	_add_button_feedback(_start_button, true)
	for btn: Button in _difficulty_buttons.values():
		_add_button_feedback(btn)
	for btn2: Button in _shape_buttons.values():
		_add_button_feedback(btn2)
	_add_button_feedback(_leaderboard_button)
	_add_button_feedback(_settings_button)
	_apply_start_button_style()


func _load_gallery() -> void:
	_gallery_textures.clear()
	_gallery_paths.clear()

	for path: String in DEFAULT_IMAGE_PATHS:
		var img := Image.load_from_file(path)
		if img != null:
			_limit_image_size(img)
			_gallery_textures.append(ImageTexture.create_from_image(img))
			_gallery_paths.append(path)

	_load_user_gallery()

	if _gallery_textures.is_empty():
		var placeholder := Image.create(220, 160, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0.2, 0.2, 0.24))
		var tex := ImageTexture.create_from_image(placeholder)
		_gallery_textures.append(tex)
		_gallery_paths.append("")


func _load_user_gallery() -> void:
	var dir := DirAccess.open(USER_GALLERY_DIR)
	if dir == null:
		return

	const ALLOWED_EXTS: Array[String] = ["png", "jpg", "jpeg", "webp"]
	dir.list_dir_begin()
	var fname := dir.get_next()
	var files: Array[String] = []
	while fname != "":
		if not dir.current_is_dir() and not fname.begins_with("."):
			if ALLOWED_EXTS.has(fname.get_extension().to_lower()):
				files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()

	for f: String in files:
		var path := USER_GALLERY_DIR + f
		var img := Image.load_from_file(path)
		if img != null:
			_limit_image_size(img)
			_gallery_textures.append(ImageTexture.create_from_image(img))
			_gallery_paths.append(path)


func _build_scene_cards() -> void:
	_scene_cards.clear()
	for child in _scene_grid.get_children():
		child.queue_free()

	for i in range(_gallery_textures.size()):
		var card := SceneCardScene.instantiate() as Button
		card.button_group = _scene_group
		card.set("scene_texture", _gallery_textures[i])
		card.set("scene_path", _gallery_paths[i])
		card.set("scene_index", i)
		var idx := i
		card.pressed.connect(func() -> void: _on_scene_selected(idx))
		_scene_grid.add_child(card)
		_scene_cards.append(card)


func _restore_previous_selection() -> void:
	_set_shape(GameState.piece_shape)

	if GameState.difficulty_explicitly_set:
		var saved_diff := _find_difficulty_key(GameState.cols, GameState.rows)
		if saved_diff != "":
			_set_difficulty(saved_diff)
	else:
		_set_difficulty(difficulty)

	if _rotation_toggle != null:
		_rotation_toggle.button_pressed = GameState.allow_rotation
	if _snap_toggle != null:
		_snap_toggle.button_pressed = GameState.snap_to_board

	if GameState.image_texture != null:
		var idx := GameState.gallery_index
		if idx >= 0 and idx < _scene_cards.size():
			_on_scene_selected(idx)
			return

	_on_scene_selected(0)


func _on_scene_selected(index: int) -> void:
	if index < 0 or index >= _gallery_textures.size():
		return
	selected_scene = _gallery_textures[index]
	selected_path = _gallery_paths[index]
	selected_index = index

	for i in range(_scene_cards.size()):
		var card := _scene_cards[i]
		if "set_selected" in card:
			card.call("set_selected", i == index)
		else:
			card.button_pressed = (i == index)


func _init_difficulty_buttons() -> void:
	var group := ButtonGroup.new()
	for entry: Dictionary in DIFFICULTIES:
		var key: String = entry["key"]
		if _difficulty_buttons.has(key):
			var btn := _difficulty_buttons[key] as Button
			btn.button_group = group
			btn.toggle_mode = true
			btn.pressed.connect(func() -> void: _set_difficulty(key))

	_set_difficulty(difficulty)


func _init_shape_buttons() -> void:
	var group := ButtonGroup.new()
	for entry: Dictionary in SHAPES:
		var key: String = entry["key"]
		if _shape_buttons.has(key):
			var btn := _shape_buttons[key] as Button
			btn.button_group = group
			btn.toggle_mode = true
			btn.pressed.connect(func() -> void: _set_shape(key))

	_set_shape(shape)


func _set_difficulty(key: String) -> void:
	difficulty = key
	for entry: Dictionary in DIFFICULTIES:
		var entry_key: String = entry["key"]
		if _difficulty_buttons.has(entry_key):
			var btn := _difficulty_buttons[entry_key] as Button
			btn.button_pressed = (entry_key == key)


func _set_shape(key: String) -> void:
	shape = key
	for entry: Dictionary in SHAPES:
		var entry_key: String = entry["key"]
		if _shape_buttons.has(entry_key):
			var btn := _shape_buttons[entry_key] as Button
			btn.button_pressed = (entry_key == key)


func _find_difficulty_key(cols: int, rows: int) -> String:
	for entry: Dictionary in DIFFICULTIES:
		if entry.get("cols", -1) == cols and entry.get("rows", -1) == rows:
			return entry["key"]
	return ""


func _apply_responsive_layout() -> void:
	_scene_grid.columns = 2 if UIScale.is_mobile() else 3
	if _content != null:
		var available := get_viewport_rect().size.x - 56.0
		var target_w: float = min(1100.0, max(720.0, available))
		_content.custom_minimum_size = Vector2(target_w, _content.custom_minimum_size.y)


func _on_upload_pressed() -> void:
	_upload_dialog.popup_centered(Vector2i(720, 520))


func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		_show_error("Could not load the selected image.")
		return

	_limit_image_size(img)
	var saved_path := _save_user_image(path, img)
	var use_path := saved_path if saved_path != "" else path
	var tex := ImageTexture.create_from_image(img)

	_gallery_textures.append(tex)
	_gallery_paths.append(use_path)
	var new_index := _gallery_textures.size() - 1

	var card := SceneCardScene.instantiate() as Button
	card.button_group = _scene_group
	card.set("scene_texture", tex)
	card.set("scene_path", use_path)
	card.set("scene_index", new_index)
	card.pressed.connect(func() -> void: _on_scene_selected(new_index))
	_scene_grid.add_child(card)
	_scene_cards.append(card)

	_on_scene_selected(new_index)


func _save_user_image(src_path: String, img: Image) -> String:
	var abs_dir := ProjectSettings.globalize_path(USER_GALLERY_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	var base_name := src_path.get_file().get_basename()
	var ext := src_path.get_extension().to_lower()
	if ext == "":
		ext = "png"

	var dest_path := _unique_user_gallery_path(base_name, ext)
	if _save_image_with_extension(img, dest_path, ext):
		return dest_path
	if ext != "png":
		dest_path = _unique_user_gallery_path(base_name, "png")
		if _save_image_with_extension(img, dest_path, "png"):
			return dest_path
	return ""


func _unique_user_gallery_path(base_name: String, ext: String) -> String:
	var use_ext := ext if ext != "" else "png"
	var dest_path := USER_GALLERY_DIR + "%s.%s" % [base_name, use_ext]
	var counter := 1
	while FileAccess.file_exists(dest_path):
		dest_path = USER_GALLERY_DIR + "%s_%d.%s" % [base_name, counter, use_ext]
		counter += 1
	return dest_path


func _save_image_with_extension(img: Image, dest_path: String, ext: String) -> bool:
	var abs_dest := ProjectSettings.globalize_path(dest_path)
	var err: int = FAILED
	match ext:
		"png":
			err = img.save_png(abs_dest)
		"jpg", "jpeg":
			err = img.save_jpg(abs_dest, 0.9)
		"webp":
			err = img.save_webp(abs_dest)
		_:
			return false
	return err == OK


func _limit_image_size(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w <= MAX_IMAGE_DIMENSION and h <= MAX_IMAGE_DIMENSION:
		return
	var scale: float = float(MAX_IMAGE_DIMENSION) / float(max(w, h))
	img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_LANCZOS)


func _on_start_pressed() -> void:
	if selected_scene == null:
		_show_error("Please select a scene first.")
		return

	GameState.allow_rotation = _rotation_toggle.button_pressed if _rotation_toggle != null else GameState.allow_rotation
	GameState.snap_to_board = _snap_toggle.button_pressed if _snap_toggle != null else GameState.snap_to_board

	PuzzleConfig.scene = selected_scene
	PuzzleConfig.scene_path = selected_path
	PuzzleConfig.gallery_index = selected_index
	PuzzleConfig.difficulty = difficulty
	PuzzleConfig.shape = shape
	PuzzleConfig.apply_to_game_state()

	get_tree().change_scene_to_file("res://scenes/game/puzzle_scene.tscn")


func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/leaderboard.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")


func _show_error(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Oops"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)


func _refresh_resume_button(show: bool) -> void:
	if _resume_button == null:
		return
	_resume_button.visible = show
	_resume_button.disabled = not show


func _on_resume_pressed() -> void:
	if not _load_saved_puzzle_data():
		_show_error("No saved puzzle found to resume.")
		_refresh_resume_button(false)
		GameState.has_save = false
		return

	GameState.resume_save = true
	get_tree().change_scene_to_file("res://scenes/game/puzzle_scene.tscn")


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

	# Sync the menu selection to the saved slot if possible.
	if GameState.gallery_index >= 0 and GameState.gallery_index < _scene_cards.size():
		_on_scene_selected(GameState.gallery_index)
	var saved_diff := _find_difficulty_key(GameState.cols, GameState.rows)
	if saved_diff != "":
		_set_difficulty(saved_diff)
	_set_shape(GameState.piece_shape)
	_refresh_resume_button(true)
	return true


func _apply_start_button_style() -> void:
	var accent := get_theme_color("accent_color", "Button")
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.shadow_size = 12
	normal.shadow_color = Color(0, 0, 0, 0.12)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.12)

	_start_button.add_theme_stylebox_override("normal", normal)
	_start_button.add_theme_stylebox_override("hover", hover)
	_start_button.add_theme_stylebox_override("pressed", pressed)
	_start_button.add_theme_color_override("font_color", Color(1, 1, 1))


func _add_button_feedback(btn: Button, brighten_on_hover: bool = false) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	btn.mouse_entered.connect(func() -> void:
		_create_feedback_tween(btn, Vector2(1.05, 1.05), 0.12)
		if brighten_on_hover:
			btn.modulate = Color(1.05, 1.05, 1.05, 1)
	)
	btn.mouse_exited.connect(func() -> void:
		_create_feedback_tween(btn, Vector2(1, 1), 0.12)
		if brighten_on_hover:
			btn.modulate = Color(1, 1, 1, 1)
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
