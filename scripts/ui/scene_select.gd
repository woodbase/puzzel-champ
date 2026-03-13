extends Control

const DEFAULT_IMAGE_PATHS: Array[String] = [
	"res://gfx/puzzles/pexels-harun-tan-2311991-3980364.jpg",
	"res://gfx/puzzles/pexels-pixabay-206768.jpg",
	"res://gfx/puzzles/pexels-pixabay-268533.jpg",
	"res://gfx/puzzles/pexels-robshumski-1903702.jpg",
	"res://gfx/puzzles/pexels-connorscottmcmanus-28368352.jpg",
]

const USER_GALLERY_DIR := "user://gallery/"
const MAX_IMAGE_DIMENSION := 2048

const SceneCardScene := preload("res://scenes/ui/components/SceneCard.tscn")

const DIFFICULTIES: Array[Dictionary] = [
	{"key": "easy", "label": "Easy", "cols": 3, "rows": 2, "color": Color(0.32, 0.74, 0.42)},
	{"key": "medium", "label": "Medium", "cols": 4, "rows": 3, "color": Color(0.32, 0.62, 0.92)},
	{"key": "hard", "label": "Hard", "cols": 6, "rows": 4, "color": Color(0.96, 0.63, 0.28)},
	{"key": "expert", "label": "Expert", "cols": 8, "rows": 6, "color": Color(0.9, 0.28, 0.24)},
]

const PIECE_STYLES: Array[Dictionary] = [
	{"key": "square", "label": "Square", "icon": "⬜"},
	{"key": "jigsaw", "label": "Jigsaw", "icon": "🧩"},
]

var selected_scene: Texture2D = null
var selected_path: String = ""
var selected_index: int = -1
var difficulty: String = "medium"
var piece_style: String = "jigsaw"

var _gallery_textures: Array[Texture2D] = []
var _gallery_paths: Array[String] = []
var _scene_cards: Array[Button] = []
var _scene_group := ButtonGroup.new()
var _preview_tween: Tween = null

@onready var _main_layout: BoxContainer = %MainLayout
@onready var _scene_grid: GridContainer = %SceneGrid
@onready var _upload_button: Button = %UploadImageButton
@onready var _upload_dialog: FileDialog = $UploadDialog
@onready var _preview_image: TextureRect = %PreviewImage
@onready var _start_button: Button = %StartPuzzleButton
@onready var _back_button: Button = %BackButton
@onready var _back_icon_button: Button = %BackIconButton

@onready var _difficulty_buttons: Dictionary = {
	"easy": %EasyButton,
	"medium": %MediumButton,
	"hard": %HardButton,
	"expert": %ExpertButton,
}

@onready var _piece_style_buttons: Dictionary = {
	"square": %SquareButton,
	"jigsaw": %JigsawButton,
}


func _ready() -> void:
	_upload_button.pressed.connect(_on_upload_pressed)
	_upload_dialog.file_selected.connect(_on_file_selected)
	_start_button.pressed.connect(_on_start_puzzle_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	if _back_icon_button != null:
		_back_icon_button.pressed.connect(_on_back_pressed)
	UIScale.layout_changed.connect(_apply_responsive_layout)

	_init_difficulty_buttons()
	_init_piece_style_buttons()

	_load_gallery()
	_build_scene_cards()
	_restore_previous_selection()

	_apply_start_button_style()
	_style_upload_button()
	_style_back_button()
	_add_button_feedback(_upload_button)
	_add_button_feedback(_start_button, true)
	_add_button_feedback(_back_button)
	if _back_icon_button != null:
		_add_button_feedback(_back_icon_button)
	for btn: Button in _difficulty_buttons.values():
		_add_button_feedback(btn)
	for btn2: Button in _piece_style_buttons.values():
		_add_button_feedback(btn2)

	_apply_responsive_layout()


func _init_difficulty_buttons() -> void:
	var group := ButtonGroup.new()
	for entry: Dictionary in DIFFICULTIES:
		var key: String = entry["key"]
		if _difficulty_buttons.has(key):
			var btn := _difficulty_buttons[key] as Button
			btn.button_group = group
			btn.toggle_mode = true
			btn.text = entry["label"]
			btn.pressed.connect(func() -> void: _set_difficulty(key))
	_style_difficulty_buttons()


func _init_piece_style_buttons() -> void:
	var group := ButtonGroup.new()
	for entry: Dictionary in PIECE_STYLES:
		var key: String = entry["key"]
		if _piece_style_buttons.has(key):
			var btn := _piece_style_buttons[key] as Button
			btn.button_group = group
			btn.toggle_mode = true
			btn.text = "%s %s" % [entry.get("icon", ""), entry["label"]]
			btn.pressed.connect(func() -> void: _set_piece_style(key))
	_style_piece_style_buttons()


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
	if _scene_grid == null:
		push_warning("_scene_grid is null; SceneGrid node may be missing from the scene.")
		return
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
	_set_piece_style(GameState.piece_shape)

	if GameState.difficulty_explicitly_set:
		var saved := _find_difficulty_key(GameState.cols, GameState.rows)
		if saved != "":
			_set_difficulty(saved)
	else:
		_set_difficulty("easy" if GameState.is_mobile else difficulty)

	if GameState.image_texture != null:
		var idx := GameState.gallery_index
		if idx >= 0 and idx < _scene_cards.size():
			_on_scene_selected(idx)
			return

	_on_scene_selected(0)


func _set_difficulty(key: String) -> void:
	difficulty = key
	for entry: Dictionary in DIFFICULTIES:
		var entry_key: String = entry["key"]
		if _difficulty_buttons.has(entry_key):
			var btn := _difficulty_buttons[entry_key] as Button
			btn.button_pressed = (entry_key == key)
	_style_difficulty_buttons()


func _set_piece_style(key: String) -> void:
	piece_style = key
	for entry: Dictionary in PIECE_STYLES:
		var entry_key: String = entry["key"]
		if _piece_style_buttons.has(entry_key):
			var btn := _piece_style_buttons[entry_key] as Button
			btn.button_pressed = (entry_key == key)
	_style_piece_style_buttons()


func _find_difficulty_key(cols: int, rows: int) -> String:
	for entry: Dictionary in DIFFICULTIES:
		if entry.get("cols", -1) == cols and entry.get("rows", -1) == rows:
			return entry["key"]
	return ""


func _apply_responsive_layout() -> void:
	var width := minf(get_viewport_rect().size.x, 1100.0)
	_set_layout_vertical(width < 900.0)

	var columns := 4
	if width < 1280.0:
		columns = 3
	if width < 960.0:
		columns = 2
	_scene_grid.columns = columns


func _set_layout_vertical(vertical: bool) -> void:
	if vertical and not (_main_layout is VBoxContainer):
		_swap_layout(VBoxContainer.new())
	elif not vertical and not (_main_layout is HBoxContainer):
		_swap_layout(HBoxContainer.new())


func _swap_layout(new_layout: BoxContainer) -> void:
	if _main_layout == null:
		return
	var parent := _main_layout.get_parent()
	if parent == null:
		return
	var idx := _main_layout.get_index()
	var sep := _main_layout.get_theme_constant("separation")

	new_layout.name = _main_layout.name
	new_layout.size_flags_horizontal = _main_layout.size_flags_horizontal
	new_layout.size_flags_vertical = _main_layout.size_flags_vertical
	new_layout.add_theme_constant_override("separation", sep)

	var children := _main_layout.get_children()
	for child in children:
		_main_layout.remove_child(child)
		new_layout.add_child(child)

	parent.remove_child(_main_layout)
	parent.add_child(new_layout)
	parent.move_child(new_layout, idx)
	_main_layout.queue_free()
	_main_layout = new_layout


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

	_update_preview(selected_scene)
	_start_button.disabled = selected_scene == null


func _update_preview(tex: Texture2D) -> void:
	if _preview_image == null:
		return
	if _preview_tween != null and _preview_tween.is_running():
		_preview_tween.kill()
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview_image, "modulate:a", 0.0, 0.08).set_trans(Tween.TRANS_SINE)
	_preview_tween.tween_callback(func() -> void: _preview_image.texture = tex)
	_preview_tween.tween_property(_preview_image, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)


func _on_start_puzzle_pressed() -> void:
	if selected_scene == null:
		_show_error("Please select a scene first.")
		return

	PuzzleConfig.scene = selected_scene
	PuzzleConfig.scene_path = selected_path
	PuzzleConfig.gallery_index = selected_index
	PuzzleConfig.difficulty = difficulty
	PuzzleConfig.shape = piece_style
	PuzzleConfig.apply_to_game_state()

	get_tree().change_scene_to_file("res://scenes/game/puzzle_scene.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _show_error(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Oops"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)


func _apply_start_button_style() -> void:
	_apply_pill_style(_start_button, Color(0.88, 0.66, 0.08), Color(1.0, 0.88, 0.28), 22)


func _style_upload_button() -> void:
	_apply_pill_style(_upload_button, Color(0.2, 0.4, 0.76), Color(0.44, 0.66, 0.98), 20)


func _style_back_button() -> void:
	_apply_pill_style(_back_button, Color(0.18, 0.36, 0.62), Color(0.36, 0.6, 0.9), 20)


func _apply_pill_style(btn: Button, base: Color, highlight: Color, radius: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.corner_radius_top_left = radius
	normal.corner_radius_top_right = radius
	normal.corner_radius_bottom_left = radius
	normal.corner_radius_bottom_right = radius
	normal.shadow_size = 12
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
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


func _style_difficulty_buttons() -> void:
	for entry: Dictionary in DIFFICULTIES:
		var key: String = entry["key"]
		if not _difficulty_buttons.has(key):
			continue
		var btn := _difficulty_buttons[key] as Button
		var base: Color = entry["color"]
		var selected := difficulty == key

		var normal := StyleBoxFlat.new()
		normal.bg_color = base if selected else base.darkened(0.22)
		normal.corner_radius_top_left = 14
		normal.corner_radius_top_right = 14
		normal.corner_radius_bottom_left = 14
		normal.corner_radius_bottom_right = 14
		normal.shadow_size = 10
		normal.shadow_color = Color(0, 0, 0, 0.18)
		if selected:
			normal.border_width_left = 2
			normal.border_width_top = 2
			normal.border_width_right = 2
			normal.border_width_bottom = 2
			normal.border_color = Color(1, 1, 1, 0.82)

		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = base.lightened(0.08)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = base.darkened(0.06)

		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))


func _style_piece_style_buttons() -> void:
	for entry: Dictionary in PIECE_STYLES:
		var key: String = entry["key"]
		if not _piece_style_buttons.has(key):
			continue
		var btn := _piece_style_buttons[key] as Button
		var selected := piece_style == key
		var base := Color(0.28, 0.44, 0.72)

		var normal := StyleBoxFlat.new()
		normal.bg_color = base.lightened(0.16) if selected else base.darkened(0.2)
		normal.corner_radius_top_left = 14
		normal.corner_radius_top_right = 14
		normal.corner_radius_bottom_left = 14
		normal.corner_radius_bottom_right = 14
		normal.shadow_size = 8
		normal.shadow_color = Color(0, 0, 0, 0.14)
		if selected:
			normal.border_width_left = 2
			normal.border_width_top = 2
			normal.border_width_right = 2
			normal.border_width_bottom = 2
			normal.border_color = Color(1, 1, 1, 0.72)

		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = base.lightened(0.24)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = base.darkened(0.08)

		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))


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
