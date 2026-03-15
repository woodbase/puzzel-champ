extends Control

# ─── Difficulty presets ───────────────────────────────────────────────────────
# Ordered from easiest to most challenging, with exponential piece-count growth.
# Each level approximately doubles the number of pieces from the previous level,
# providing a natural difficulty progression for players.
const DIFFICULTIES: Array[Dictionary] = [
	{"label": "Easy",   "cols": 3, "rows": 2, "desc": "Perfect for beginners"},
	{"label": "Medium", "cols": 4, "rows": 3, "desc": "A balanced challenge"},
	{"label": "Hard",   "cols": 6, "rows": 4, "desc": "For experienced players"},
	{"label": "Expert", "cols": 8, "rows": 6, "desc": "The ultimate test"},
]

# ─── Piece shape presets ──────────────────────────────────────────────────────
const SHAPES: Array[Dictionary] = [
	{"label": "Square", "key": "square"},
	{"label": "Jigsaw", "key": "jigsaw"},
]

# ─── UI icon assets ───────────────────────────────────────────────────────────
const ICON_PLAY     := preload("res://gfx/ui/icons/icon_play.png")
const ICON_TROPHY   := preload("res://gfx/ui/icons/icon_trophy.png")
const ICON_SETTINGS := preload("res://gfx/ui/icons/icon_settings.png")
const ICON_DELETE   := preload("res://gfx/ui/icons/icon_delete.png")

# ─── Default puzzle images bundled with the game ─────────────────────────────
const DEFAULT_IMAGE_PATHS: Array[String] = [
	"res://gfx/puzzles/pexels-harun-tan-2311991-3980364.jpg",
	"res://gfx/puzzles/pexels-pixabay-206768.jpg",
	"res://gfx/puzzles/pexels-pixabay-268533.jpg",
	"res://gfx/puzzles/pexels-robshumski-1903702.jpg",
	"res://gfx/puzzles/pexels-connorscottmcmanus-28368352.jpg",
]

## Directory inside the user's data folder where uploaded images are stored.
const USER_GALLERY_DIR := "user://gallery/"

# ─── Colour constants ─────────────────────────────────────────────────────────
const BG_COLOR       := Color(0.10, 0.12, 0.17)
const PANEL_COLOR    := Color(0.15, 0.17, 0.22)
const ITEM_COLOR     := Color(0.20, 0.22, 0.30)
const ACCENT_COLOR   := Color(0.55, 0.35, 0.90)
const BTN_COLOR      := Color(0.28, 0.18, 0.52)
const TEXT_COLOR     := Color(0.88, 0.82, 0.98)
const SUBTEXT_COLOR  := Color(0.58, 0.55, 0.68)

## Side length (px) of each square gallery thumbnail.
const THUMBNAIL_SIZE := 96

## Larger thumbnail side length (px) used in portrait / mobile orientation for
## easier touch targeting.
const THUMBNAIL_SIZE_PORTRAIT := 120

## Maximum pixel dimension (width or height) for full-resolution textures kept
## in memory.  Images larger than this are downscaled before being uploaded to
## the GPU, reducing memory usage while retaining enough detail for all
## realistic screen sizes and difficulty settings.
const MAX_FULL_RES_DIMENSION: int = 2048

# ─── State ────────────────────────────────────────────────────────────────────
var _selected_texture: Texture2D = null
var _selected_path: String       = ""
var _active_gallery_idx: int     = -1
var _difficulty_index: int       = 1
var _shape_index: int            = 1  # default: Jigsaw

var _gallery_textures: Array[ImageTexture] = []
## Filesystem / resource paths matching each entry in _gallery_textures.
var _gallery_paths: Array[String]               = []
## Small (THUMBNAIL_SIZE²) textures used in the gallery grid to save memory.
var _gallery_thumb_textures: Array[ImageTexture] = []
var _gallery_items: Array[PanelContainer]  = []
var _diff_btns: Array[Button]              = []
var _shape_btns: Array[Button]             = []

var _preview_rect: TextureRect   = null
var _no_image_lbl: Label         = null
var _piece_count_lbl: Label      = null
var _difficulty_desc_lbl: Label  = null
var _start_btn: Button           = null
var _resume_btn: Button          = null
var _file_dialog: FileDialog     = null
var _gallery_grid: GridContainer = null  # kept for dynamic item insertion

## True when the player is using a custom piece count instead of a preset.
var _use_custom: bool = false
## The last custom piece count entered by the player (used when _use_custom is true).
var _custom_piece_count: int = 100
## The custom difficulty button (desktop only).
var _custom_btn: Button = null
## Container for the custom piece-count SpinBox row (desktop only).
var _custom_container: Control = null
## SpinBox for entering a custom piece count (desktop only).
var _custom_spin: SpinBox = null
## Top-level layout container (HBoxContainer in landscape, VBoxContainer in portrait).
var _content_row: Control        = null
var _gallery_panel: Control      = null
var _settings_panel: Control     = null
## Title and subtitle labels stored so they can be resized on orientation change.
var _title_lbl: Label            = null
var _subtitle_lbl: Label         = null
## Outer margin container stored so its margins can be updated on layout changes.
var _outer_margin: MarginContainer = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_gallery_textures()
	_build_ui()
	UIScale.layout_changed.connect(_on_viewport_size_changed)

	# Restore state from a previous game session.
	if GameState.image_texture != null:
		var gi := GameState.gallery_index
		if gi >= 0 and gi < _gallery_textures.size():
			_select_gallery_item(gi)
		else:
			_apply_selection(GameState.image_texture, GameState.image_path, -1)
	else:
		_select_gallery_item(0)

	# On first load (no game started yet) auto-select a sensible default
	# based on screen size; otherwise restore the player's last choice.
	if GameState.difficulty_explicitly_set:
		if not UIScale.is_mobile() and not _is_preset_difficulty(GameState.cols, GameState.rows):
			# Restore a previously saved custom piece count.
			_custom_piece_count = GameState.cols * GameState.rows
			_apply_custom()
		else:
			_apply_difficulty(_find_difficulty_index(GameState.cols, GameState.rows))
	else:
		_apply_difficulty(_default_difficulty_for_screen())

	_apply_shape(
		_find_shape_index(GameState.piece_shape)
	)

# ─── Texture generation ───────────────────────────────────────────────────────

func _build_gallery_textures() -> void:
	_gallery_textures.clear()
	_gallery_thumb_textures.clear()
	_gallery_paths.clear()

	# Load the default puzzle images shipped with the game.
	for path: String in DEFAULT_IMAGE_PATHS:
		var img := Image.load_from_file(path)
		if img != null:
			_gallery_textures.append(null)  # full-res loaded lazily on selection
			_gallery_thumb_textures.append(_make_thumbnail(img))
			_gallery_paths.append(path)

	# Load any images the user has previously uploaded.
	_load_user_gallery_textures()

	# Ensure the gallery always has at least one entry so selection logic
	# can't produce an index-out-of-bounds error when all loads fail.
	if _gallery_textures.is_empty():
		var placeholder := Image.create(THUMBNAIL_SIZE, THUMBNAIL_SIZE, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0.20, 0.22, 0.30))
		var placeholder_tex := ImageTexture.create_from_image(placeholder)
		_gallery_textures.append(placeholder_tex)
		_gallery_thumb_textures.append(placeholder_tex)
		_gallery_paths.append("")


## Scans user://gallery/ and appends any saved images to the gallery arrays.
func _load_user_gallery_textures() -> void:
	var dir := DirAccess.open(USER_GALLERY_DIR)
	if dir == null:
		return
	const ALLOWED_EXTS: Array[String] = ["png", "jpg", "jpeg", "bmp", "webp"]
	var files: Array[String] = []
	# skip_navigational=true skips "." and ".."
	# skip_hidden=true skips dot-files like .DS_Store
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not fname.begins_with("."):
			if ALLOWED_EXTS.has(fname.get_extension().to_lower()):
				files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()  # stable ordering across sessions
	for fname2: String in files:
		var path := USER_GALLERY_DIR + fname2
		var img := Image.load_from_file(path)
		if img != null:
			_gallery_textures.append(null)  # full-res loaded lazily on selection
			_gallery_thumb_textures.append(_make_thumbnail(img))
			_gallery_paths.append(path)


## Copies a (possibly resized) image into user://gallery/ and returns the path.
## Returns "" on failure.  A unique filename is chosen if one already exists.
func _save_user_image(src_path: String, img: Image) -> String:
	# Ensure the directory exists.
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


## Returns a unique user://gallery/ path using *base_name* and *ext*.
func _unique_user_gallery_path(base_name: String, ext: String) -> String:
	var use_ext := ext if ext != "" else "png"
	var dest_path := USER_GALLERY_DIR + "%s.%s" % [base_name, use_ext]
	var counter := 1
	while FileAccess.file_exists(dest_path):
		dest_path = USER_GALLERY_DIR + "%s_%d.%s" % [base_name, counter, use_ext]
		counter += 1
	return dest_path


## Saves *img* to *dest_path* using the requested extension. Returns false on failure.
func _save_image_with_extension(img: Image, dest_path: String, ext: String) -> bool:
	var abs_dest := ProjectSettings.globalize_path(dest_path)
	var err: int = FAILED
	match ext:
		"png":
			err = img.save_png(abs_dest)
		"jpg", "jpeg":
			err = img.save_jpg(abs_dest, 0.9)
		"bmp":
			err = img.save_bmp(abs_dest)
		"tga":
			err = img.save_tga(abs_dest)
		"webp":
			err = img.save_webp(abs_dest)
		_:
			return false
	return err == OK


## Returns a THUMBNAIL_SIZE × THUMBNAIL_SIZE ImageTexture scaled from *img*.
## The original Image object is not modified.
func _make_thumbnail(img: Image) -> ImageTexture:
	var copy := img.duplicate() as Image
	copy.resize(THUMBNAIL_SIZE, THUMBNAIL_SIZE, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(copy)


## Resizes *img* in-place so that neither dimension exceeds MAX_FULL_RES_DIMENSION,
## preserving the aspect ratio.  Has no effect when the image is already within bounds.
## Using INTERPOLATE_LANCZOS gives high-quality downscaling with minimal aliasing.
func _limit_image_size(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w <= MAX_FULL_RES_DIMENSION and h <= MAX_FULL_RES_DIMENSION:
		return
	var scale: float = float(MAX_FULL_RES_DIMENSION) / float(max(w, h))
	img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_LANCZOS)

# ─── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen background.
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer margin – stored so it can be updated when the layout changes.
	_outer_margin = MarginContainer.new()
	_outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe_insets := UIScale.safe_area_insets()
	_outer_margin.add_theme_constant_override("margin_left",   UIScale.px(40) + int(safe_insets["left"]))
	_outer_margin.add_theme_constant_override("margin_right",  UIScale.px(40) + int(safe_insets["right"]))
	_outer_margin.add_theme_constant_override("margin_top",    UIScale.px(28) + int(safe_insets["top"]))
	_outer_margin.add_theme_constant_override("margin_bottom", UIScale.px(28) + int(safe_insets["bottom"]))
	add_child(_outer_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", UIScale.px(16))
	_outer_margin.add_child(root_vbox)

	root_vbox.add_child(_build_title_section())

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.28, 0.28, 0.40))
	root_vbox.add_child(sep)

	# Choose a side-by-side (landscape) or stacked (portrait) layout.
	var is_portrait := UIScale.is_portrait()
	var content_row: BoxContainer
	if is_portrait:
		content_row = VBoxContainer.new()
	else:
		content_row = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", UIScale.px(20))
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_row)

	_gallery_panel  = _build_gallery_panel(is_portrait)
	_settings_panel = _build_settings_panel()
	content_row.add_child(_gallery_panel)
	content_row.add_child(_settings_panel)
	_content_row = content_row


func _build_title_section() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var portrait := UIScale.is_portrait()

	_title_lbl = Label.new()
	_title_lbl.text = "Puzzle Champ"
	_title_lbl.add_theme_font_size_override("font_size", UIScale.font_size(36 if portrait else 46))
	_title_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "Pick an image from the gallery or upload your own, then start your puzzle!"
	_subtitle_lbl.add_theme_font_size_override("font_size", UIScale.font_size(16))
	_subtitle_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.visible = not portrait
	vbox.add_child(_subtitle_lbl)

	return vbox


func _build_gallery_panel(portrait_layout: bool = false) -> Control:
	var panel := _make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var margin := _make_inner_margin(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Section header.
	var hdr := Label.new()
	hdr.text = "Choose an Image"
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", TEXT_COLOR)
	vbox.add_child(hdr)

	# Scrollable thumbnail grid.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 2 if portrait_layout else 3
	_gallery_grid.add_theme_constant_override("h_separation", 10)
	_gallery_grid.add_theme_constant_override("v_separation", 10)
	_gallery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_gallery_grid)

	_gallery_items.clear()
	for i in range(_gallery_textures.size()):
		var item := _build_gallery_item(i)
		_gallery_grid.add_child(item)
		_gallery_items.append(item)

	# Upload button.
	var upload_btn := _make_button("Upload Your Own Image")
	upload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_btn.pressed.connect(_on_upload_pressed)
	vbox.add_child(upload_btn)

	return panel


func _build_gallery_item(index: int) -> PanelContainer:
	var container := PanelContainer.new()
	# Use a larger touch target in portrait / mobile orientation.
	var thumb_size := THUMBNAIL_SIZE_PORTRAIT if _is_portrait() else THUMBNAIL_SIZE
	container.custom_minimum_size = Vector2(thumb_size, thumb_size)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_gallery_item_style(container, false)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   3)
	inner.add_theme_constant_override("margin_right",  3)
	inner.add_theme_constant_override("margin_top",    3)
	inner.add_theme_constant_override("margin_bottom", 3)
	container.add_child(inner)

	var tex_rect := TextureRect.new()
	tex_rect.texture      = _gallery_thumb_textures[index]
	tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tex_rect)

	var i := index
	container.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_select_gallery_item(i)
	)

	# Add a delete button overlay for user-uploaded images (identified by
	# their user:// path prefix).  Default bundled images cannot be deleted.
	if index < _gallery_paths.size() and _gallery_paths[index].begins_with("user://"):
		var overlay := Control.new()
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(overlay)

		var del_btn := Button.new()
		del_btn.icon = ICON_DELETE
		del_btn.anchor_left   = 1.0
		del_btn.anchor_top    = 0.0
		del_btn.anchor_right  = 1.0
		del_btn.anchor_bottom = 0.0
		del_btn.offset_left   = -24
		del_btn.offset_top    = 2
		del_btn.offset_right  = -2
		del_btn.offset_bottom = 24
		del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		del_btn.add_theme_color_override("icon_normal_color", Color.WHITE)
		del_btn.add_theme_color_override("icon_hover_color", Color.WHITE)
		del_btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			match state:
				"normal":  sb.bg_color = Color(0.60, 0.10, 0.10, 0.85)
				"hover":   sb.bg_color = Color(0.85, 0.15, 0.15, 0.95)
				"pressed": sb.bg_color = Color(0.45, 0.08, 0.08, 0.95)
			_set_corner_radius(sb, 4)
			del_btn.add_theme_stylebox_override(state, sb)
		del_btn.pressed.connect(func() -> void: _on_delete_gallery_item(i))
		overlay.add_child(del_btn)

	return container


func _build_settings_panel() -> Control:
	var panel := _make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var margin := _make_inner_margin(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Preview ──
	var prev_hdr := Label.new()
	prev_hdr.text = "Preview"
	prev_hdr.add_theme_font_size_override("font_size", 20)
	prev_hdr.add_theme_color_override("font_color", TEXT_COLOR)
	vbox.add_child(prev_hdr)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 170)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = Color(0.08, 0.09, 0.13)
	_set_corner_radius(prev_style, 8)
	preview_panel.add_theme_stylebox_override("panel", prev_style)
	vbox.add_child(preview_panel)

	var preview_inner := CenterContainer.new()
	preview_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_panel.add_child(preview_inner)

	var preview_stack := VBoxContainer.new()
	preview_stack.add_theme_constant_override("separation", 6)
	preview_inner.add_child(preview_stack)

	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(260, 150)
	_preview_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	preview_stack.add_child(_preview_rect)

	_no_image_lbl = Label.new()
	_no_image_lbl.text = "No image selected"
	_no_image_lbl.add_theme_font_size_override("font_size", 15)
	_no_image_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
	_no_image_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_image_lbl.visible = true
	preview_stack.add_child(_no_image_lbl)

	# ── Difficulty ──
	var diff_hdr := Label.new()
	diff_hdr.text = "Difficulty"
	diff_hdr.add_theme_font_size_override("font_size", 20)
	diff_hdr.add_theme_color_override("font_color", TEXT_COLOR)
	vbox.add_child(diff_hdr)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)

	_diff_btns.clear()
	for i in range(DIFFICULTIES.size()):
		var d := DIFFICULTIES[i]
		var btn := _make_button(d["label"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var di := i
		btn.pressed.connect(func() -> void: _apply_difficulty(di))
		diff_row.add_child(btn)
		_diff_btns.append(btn)

	# "Custom" button – desktop only, lets the player type an exact piece count.
	if not UIScale.is_mobile():
		_custom_btn = _make_button("Custom")
		_custom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_custom_btn.pressed.connect(_apply_custom)
		diff_row.add_child(_custom_btn)

	_piece_count_lbl = Label.new()
	_piece_count_lbl.add_theme_font_size_override("font_size", 14)
	_piece_count_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
	vbox.add_child(_piece_count_lbl)

	_difficulty_desc_lbl = Label.new()
	_difficulty_desc_lbl.add_theme_font_size_override("font_size", 13)
	_difficulty_desc_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR.lightened(0.15))
	_difficulty_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_difficulty_desc_lbl)

	# Custom piece-count input (desktop only).
	if not UIScale.is_mobile():
		_custom_container = HBoxContainer.new()
		_custom_container.add_theme_constant_override("separation", 8)
		_custom_container.visible = false
		vbox.add_child(_custom_container)

		var spin_lbl := Label.new()
		spin_lbl.text = "Number of pieces:"
		spin_lbl.add_theme_font_size_override("font_size", 14)
		spin_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
		spin_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_custom_container.add_child(spin_lbl)

		_custom_spin = SpinBox.new()
		_custom_spin.min_value = 2
		_custom_spin.max_value = 1000
		_custom_spin.step = 1
		_custom_spin.value = _custom_piece_count
		_custom_spin.custom_minimum_size = Vector2(120, 0)
		_custom_spin.value_changed.connect(_on_custom_spin_changed)
		_custom_container.add_child(_custom_spin)

	# ── Piece Shape ──
	var shape_hdr := Label.new()
	shape_hdr.text = "Piece Shape"
	shape_hdr.add_theme_font_size_override("font_size", 20)
	shape_hdr.add_theme_color_override("font_color", TEXT_COLOR)
	vbox.add_child(shape_hdr)

	var shape_row := HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 8)
	vbox.add_child(shape_row)

	_shape_btns.clear()
	for i in range(SHAPES.size()):
		var s := SHAPES[i]
		var btn := _make_button(s["label"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var si := i
		btn.pressed.connect(func() -> void: _apply_shape(si))
		shape_row.add_child(btn)
		_shape_btns.append(btn)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# ── Resume saved puzzle (shown only when a save exists) ──
	_resume_btn = _make_resume_button()
	_resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume_btn.pressed.connect(_on_resume_pressed)
	_resume_btn.visible = GameState.has_save
	vbox.add_child(_resume_btn)
	# ── Leaderboard button ──
	var lb_btn := _make_button("Leaderboard", ICON_TROPHY)
	lb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_btn.pressed.connect(_show_leaderboard)
	vbox.add_child(lb_btn)

	# ── Settings button ──
	var settings_btn := _make_button("Settings", ICON_SETTINGS)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_btn.pressed.connect(_show_settings_overlay)
	vbox.add_child(settings_btn)

	# ── Start button ──
	_start_btn = _make_button("Start Puzzle")
	_start_btn.custom_minimum_size = Vector2(0, 54)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.add_theme_font_size_override("font_size", 22)
	_start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_btn)

	return panel

# ─── Widget helpers ───────────────────────────────────────────────────────────

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	_set_corner_radius(style, 10)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_inner_margin(parent: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   18)
	m.add_theme_constant_override("margin_right",  18)
	m.add_theme_constant_override("margin_top",    18)
	m.add_theme_constant_override("margin_bottom", 18)
	parent.add_child(m)
	return m


func _make_button(label_text: String, icon: Texture2D = null) -> Button:
	var btn := Button.new()
	btn.text = label_text
	if icon:
		btn.icon = icon
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	var portrait := UIScale.is_portrait()
	btn.add_theme_font_size_override("font_size", UIScale.font_size(18 if portrait else 16))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var padding_v := UIScale.px(14.0 if portrait else 10.0)
	var padding_h := UIScale.px(16.0 if portrait else 14.0)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = BTN_COLOR
			"hover":   sb.bg_color = BTN_COLOR.lightened(0.20)
			"pressed": sb.bg_color = BTN_COLOR.darkened(0.15)
		_set_corner_radius(sb, 8)
		sb.content_margin_left   = padding_h
		sb.content_margin_right  = padding_h
		sb.content_margin_top    = padding_v
		sb.content_margin_bottom = padding_v
		btn.add_theme_stylebox_override(state, sb)

	return btn


## Creates the "Resume Saved Puzzle" button with a distinct green tint to
## differentiate it from the standard Start button.
func _make_resume_button() -> Button:
	var btn := Button.new()
	btn.text = "Resume Saved Puzzle"
	btn.icon = ICON_PLAY
	btn.add_theme_color_override("font_color", Color(0.90, 1.00, 0.92))
	var portrait := UIScale.is_portrait()
	btn.add_theme_font_size_override("font_size", UIScale.font_size(18 if portrait else 16))
	btn.custom_minimum_size = Vector2(0, 54)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var padding_v := UIScale.px(14.0 if portrait else 10.0)
	var padding_h := UIScale.px(16.0 if portrait else 14.0)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = Color(0.15, 0.42, 0.25)
			"hover":   sb.bg_color = Color(0.20, 0.54, 0.32)
			"pressed": sb.bg_color = Color(0.10, 0.30, 0.18)
		_set_corner_radius(sb, 8)
		sb.content_margin_left   = padding_h
		sb.content_margin_right  = padding_h
		sb.content_margin_top    = padding_v
		sb.content_margin_bottom = padding_v
		btn.add_theme_stylebox_override(state, sb)

	return btn


func _set_corner_radius(sb: StyleBoxFlat, r: int) -> void:
	sb.corner_radius_top_left     = r
	sb.corner_radius_top_right    = r
	sb.corner_radius_bottom_left  = r
	sb.corner_radius_bottom_right = r


func _set_gallery_item_style(item: PanelContainer, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	_set_corner_radius(sb, 6)
	if selected:
		sb.bg_color    = Color(0.38, 0.24, 0.62)
		sb.border_width_left   = 3
		sb.border_width_right  = 3
		sb.border_width_top    = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0.80, 0.65, 1.00)
	else:
		sb.bg_color = ITEM_COLOR
	item.add_theme_stylebox_override("panel", sb)

# ─── Selection state ──────────────────────────────────────────────────────────

func _select_gallery_item(index: int) -> void:
	# Lazy-load full-resolution texture on first selection.
	if _gallery_textures[index] == null and _gallery_paths[index] != "":
		var img := Image.load_from_file(_gallery_paths[index])
		if img != null:
			_limit_image_size(img)
			_gallery_textures[index] = ImageTexture.create_from_image(img)
	var path := _gallery_paths[index] if index < _gallery_paths.size() else ""
	_apply_selection(_gallery_textures[index], path, index)


func _apply_selection(texture: Texture2D, path: String, gallery_idx: int) -> void:
	_selected_texture   = texture
	_selected_path      = path
	_active_gallery_idx = gallery_idx

	# Update gallery highlights.
	for i in range(_gallery_items.size()):
		_set_gallery_item_style(_gallery_items[i], i == gallery_idx)

	# Update preview.
	if _preview_rect != null:
		_preview_rect.texture = texture
	if _no_image_lbl != null:
		_no_image_lbl.visible = (texture == null)


func _apply_difficulty(index: int) -> void:
	_difficulty_index = index
	_use_custom = false

	# Deactivate the custom button and hide the spinbox.
	if _custom_btn != null:
		var sb_c := StyleBoxFlat.new()
		_set_corner_radius(sb_c, 8)
		sb_c.bg_color = BTN_COLOR
		sb_c.content_margin_left   = 14
		sb_c.content_margin_right  = 14
		sb_c.content_margin_top    = 10
		sb_c.content_margin_bottom = 10
		_custom_btn.add_theme_stylebox_override("normal", sb_c)
	if _custom_container != null:
		_custom_container.visible = false

	# Refresh button highlight.
	for i in range(_diff_btns.size()):
		var btn := _diff_btns[i]
		var active := (i == index)
		var sb := StyleBoxFlat.new()
		_set_corner_radius(sb, 8)
		sb.bg_color = ACCENT_COLOR if active else BTN_COLOR
		if active:
			sb.border_width_left   = 2
			sb.border_width_right  = 2
			sb.border_width_top    = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(0.85, 0.75, 1.0)
		sb.content_margin_left   = 14
		sb.content_margin_right  = 14
		sb.content_margin_top    = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", sb)

	# Refresh piece-count label.
	if _piece_count_lbl != null:
		var d     := DIFFICULTIES[index]
		var total: int = d["cols"] * d["rows"]
		_piece_count_lbl.text = "%d pieces (%d \u00d7 %d grid)" % [
			total, d["cols"], d["rows"]
		]

	# Update difficulty description label.
	if _difficulty_desc_lbl != null:
		var d := DIFFICULTIES[index]
		_difficulty_desc_lbl.text = d["desc"]


func _find_difficulty_index(c: int, r: int) -> int:
	for i in range(DIFFICULTIES.size()):
		if DIFFICULTIES[i]["cols"] == c and DIFFICULTIES[i]["rows"] == r:
			return i
	return 1  # default: Medium


## Returns the most appropriate default difficulty index for the current screen.
## Mobile / small-screen devices get Easy (fewest pieces, easiest to tap);
## desktops and tablets get Medium for a balanced starting experience.
func _default_difficulty_for_screen() -> int:
	return 0 if UIScale.is_mobile() else 1  # Easy for mobile, Medium for desktop


## Returns true if the given cols/rows pair matches one of the preset difficulty levels.
func _is_preset_difficulty(c: int, r: int) -> bool:
	for d: Dictionary in DIFFICULTIES:
		if d["cols"] == c and d["rows"] == r:
			return true
	return false


## Computes the best-fit (cols, rows) pair for the requested piece count, targeting
## a 4:3 (landscape) aspect ratio.  Both dimensions are at least 1.
## The resulting cols*rows may differ slightly from n due to integer rounding.
func _cols_rows_from_piece_count(n: int) -> Vector2i:
	var cols := maxi(1, roundi(sqrt(float(n) * 4.0 / 3.0)))
	var rows := maxi(1, roundi(float(n) / float(cols)))
	return Vector2i(cols, rows)


## Activates custom piece-count mode: highlights the Custom button, shows the
## SpinBox, and refreshes the piece-count label.
func _apply_custom() -> void:
	_use_custom = true

	# Deactivate all preset difficulty buttons.
	for btn: Button in _diff_btns:
		var sb := StyleBoxFlat.new()
		_set_corner_radius(sb, 8)
		sb.bg_color = BTN_COLOR
		sb.content_margin_left   = 14
		sb.content_margin_right  = 14
		sb.content_margin_top    = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", sb)

	# Highlight the Custom button.
	if _custom_btn != null:
		var sb := StyleBoxFlat.new()
		_set_corner_radius(sb, 8)
		sb.bg_color = ACCENT_COLOR
		sb.border_width_left   = 2
		sb.border_width_right  = 2
		sb.border_width_top    = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.85, 0.75, 1.0)
		sb.content_margin_left   = 14
		sb.content_margin_right  = 14
		sb.content_margin_top    = 10
		sb.content_margin_bottom = 10
		_custom_btn.add_theme_stylebox_override("normal", sb)

	# Show the SpinBox and sync its value.
	if _custom_container != null:
		_custom_container.visible = true
	if _custom_spin != null:
		_custom_spin.set_value_no_signal(float(_custom_piece_count))

	# Refresh labels.
	_refresh_custom_labels()


## Updates the piece-count and description labels to reflect the current custom
## piece count, computing an approximate grid size.
func _refresh_custom_labels() -> void:
	var cr := _cols_rows_from_piece_count(_custom_piece_count)
	var actual := cr.x * cr.y
	if _piece_count_lbl != null:
		if actual == _custom_piece_count:
			_piece_count_lbl.text = "%d pieces (%d \u00d7 %d grid)" % [
				actual, cr.x, cr.y
			]
		else:
			_piece_count_lbl.text = "%d requested \u2192 %d pieces (%d \u00d7 %d grid)" % [
				_custom_piece_count, actual, cr.x, cr.y
			]
	if _difficulty_desc_lbl != null:
		_difficulty_desc_lbl.text = "Custom piece count"


## Called when the custom SpinBox value changes.
func _on_custom_spin_changed(value: float) -> void:
	_custom_piece_count = maxi(2, int(value))
	_refresh_custom_labels()


func _apply_shape(index: int) -> void:
	_shape_index = index

	# Refresh button highlight.
	for i in range(_shape_btns.size()):
		var btn := _shape_btns[i]
		var active := (i == index)
		var sb := StyleBoxFlat.new()
		_set_corner_radius(sb, 8)
		sb.bg_color = ACCENT_COLOR if active else BTN_COLOR
		if active:
			sb.border_width_left   = 2
			sb.border_width_right  = 2
			sb.border_width_top    = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(0.85, 0.75, 1.0)
		sb.content_margin_left   = 14
		sb.content_margin_right  = 14
		sb.content_margin_top    = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", sb)


func _find_shape_index(key: String) -> int:
	for i in range(SHAPES.size()):
		if SHAPES[i]["key"] == key:
			return i
	return 1  # default: Jigsaw

# ─── Event handlers ───────────────────────────────────────────────────────────

func _on_upload_pressed() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access    = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.add_filter("*.png,*.jpg,*.jpeg,*.bmp,*.webp", "Image Files")
		_file_dialog.file_selected.connect(_on_file_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(700, 500))


func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		_show_error("Could not load the selected image.\nPlease choose a valid PNG, JPG, BMP, or WebP file.")
		return

	_limit_image_size(img)
	# Save the image to user://gallery/ so it is available in future sessions.
	var saved_path := _save_user_image(path, img)
	var use_path := saved_path if saved_path != "" else path

	var tex := ImageTexture.create_from_image(img)
	_gallery_textures.append(tex)
	_gallery_thumb_textures.append(_make_thumbnail(img))
	_gallery_paths.append(use_path)

	# Add a new thumbnail to the grid.
	var new_index := _gallery_textures.size() - 1
	if _gallery_grid != null:
		var item := _build_gallery_item(new_index)
		_gallery_grid.add_child(item)
		_gallery_items.append(item)

	_apply_selection(tex, use_path, new_index)


## Prompts the user to confirm deletion of a user-uploaded gallery item.
func _on_delete_gallery_item(index: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Remove Image"
	dialog.dialog_text = "Remove this image from your gallery?\nThe file will be permanently deleted."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		_delete_user_gallery_item(index)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)


## Deletes the file at *index* from disk, removes it from all gallery arrays,
## rebuilds the gallery grid, and resets the selection when necessary.
func _delete_user_gallery_item(index: int) -> void:
	if index < 0 or index >= _gallery_paths.size():
		return

	var path := _gallery_paths[index]
	if path.begins_with("user://"):
		var abs_path := ProjectSettings.globalize_path(path)
		var err := DirAccess.remove_absolute(abs_path)
		if err != OK:
			_show_error("Could not delete the image file.\nPlease try again.")
			return

	_gallery_textures.remove_at(index)
	_gallery_thumb_textures.remove_at(index)
	_gallery_paths.remove_at(index)

	# Add a placeholder when the gallery becomes empty so the UI never breaks.
	if _gallery_textures.is_empty():
		var placeholder := Image.create(THUMBNAIL_SIZE, THUMBNAIL_SIZE, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0.20, 0.22, 0.30))
		var placeholder_tex := ImageTexture.create_from_image(placeholder)
		_gallery_textures.append(placeholder_tex)
		_gallery_thumb_textures.append(placeholder_tex)
		_gallery_paths.append("")

	# Update the active selection index to stay consistent after the removal.
	if _active_gallery_idx == index:
		# Deleted the selected item; select the nearest remaining one.
		var new_idx := clampi(index, 0, _gallery_textures.size() - 1)
		_active_gallery_idx = -1  # clear before calling to force a refresh
		_select_gallery_item(new_idx)
	elif _active_gallery_idx > index:
		_active_gallery_idx -= 1

	# Rebuild all gallery items so captured index closures are up-to-date.
	if _gallery_grid != null:
		for child in _gallery_grid.get_children():
			child.free()
		_gallery_items.clear()
		for i in range(_gallery_textures.size()):
			var item := _build_gallery_item(i)
			_gallery_grid.add_child(item)
			_gallery_items.append(item)
		if _active_gallery_idx >= 0 and _active_gallery_idx < _gallery_items.size():
			_set_gallery_item_style(_gallery_items[_active_gallery_idx], true)


func _on_start_pressed() -> void:
	if _selected_texture == null:
		_show_error("Please select an image first.")
		return
	GameState.difficulty_explicitly_set = true
	GameState.image_texture = _selected_texture
	GameState.image_path    = _selected_path
	GameState.gallery_index = _active_gallery_idx
	GameState.piece_shape   = SHAPES[_shape_index]["key"]
	if _use_custom:
		var cr := _cols_rows_from_piece_count(_custom_piece_count)
		GameState.cols = cr.x
		GameState.rows = cr.y
	else:
		var d := DIFFICULTIES[_difficulty_index]
		GameState.cols = d["cols"]
		GameState.rows = d["rows"]
	get_tree().change_scene_to_file("res://scenes/puzzle_board.tscn")


## Resumes the saved puzzle from the single save slot.
## Reads the save file to restore image, grid size, and piece shape in
## GameState, then sets the resume_save flag before switching scenes.
func _on_resume_pressed() -> void:
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	if file == null:
		_show_error("No saved puzzle found.")
		return
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		_show_error("Save file is corrupted. Please start a new puzzle.")
		return

	var save_data: Dictionary = json.get_data()

	# Determine image source: prefer path, fall back to gallery index.
	var img_path: String = save_data.get("image_path", "")
	var gallery_idx: int = int(save_data.get("gallery_index", -1))
	var img: Image = null

	if img_path != "":
		img = Image.load_from_file(img_path)
	if img == null and gallery_idx >= 0 and gallery_idx < _gallery_paths.size():
		img_path = _gallery_paths[gallery_idx]
		img = Image.load_from_file(img_path)
	if img == null:
		_show_error("Could not load the saved puzzle image. It may have been deleted.")
		return

	_limit_image_size(img)
	var texture := ImageTexture.create_from_image(img)

	GameState.image_texture          = texture
	GameState.image_path             = img_path
	GameState.gallery_index          = gallery_idx
	GameState.cols                   = int(save_data.get("cols", GameState.cols))
	GameState.rows                   = int(save_data.get("rows", GameState.rows))
	GameState.piece_shape            = str(save_data.get("piece_shape", GameState.piece_shape))
	GameState.allow_rotation         = bool(save_data.get("allow_rotation", false))
	GameState.difficulty_explicitly_set = true
	GameState.resume_save            = true
	get_tree().change_scene_to_file("res://scenes/puzzle_board.tscn")


func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title       = "Oops"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


# ─── Leaderboard overlay ──────────────────────────────────────────────────────

## Builds and shows a fullscreen leaderboard overlay on top of the main menu.
func _show_leaderboard() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	add_child(overlay)

	# Dimmed backdrop – clicking it closes the overlay.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				overlay.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.10, 0.22, 0.98)
	_set_corner_radius(ps, 16)
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.55, 0.35, 0.90)
	card.add_theme_stylebox_override("panel", ps)
	card.custom_minimum_size = Vector2(UIScale.px(440), UIScale.px(340))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   UIScale.px(32))
	outer.add_theme_constant_override("margin_right",  UIScale.px(32))
	outer.add_theme_constant_override("margin_top",    UIScale.px(24))
	outer.add_theme_constant_override("margin_bottom", UIScale.px(24))
	card.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)

	# Title row.
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Leaderboard"
	title_lbl.add_theme_font_size_override("font_size", UIScale.font_size(28))
	title_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := _make_button("Close")
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	title_row.add_child(close_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.28, 0.55))
	vbox.add_child(sep)

	# Scrollable scores area.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var scores_vbox := VBoxContainer.new()
	scores_vbox.add_theme_constant_override("separation", 18)
	scores_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scores_vbox)

	# One section per difficulty level.
	var any_scores := false
	for d: Dictionary in DIFFICULTIES:
		var d_cols: int = d["cols"]
		var d_rows: int = d["rows"]
		var entries: Array = GameState.get_scores_for_difficulty(d_cols, d_rows)
		if entries.is_empty():
			continue
		any_scores = true

		var diff_hdr := Label.new()
		diff_hdr.text = "%s  (%d × %d)" % [d["label"], d_cols, d_rows]
		diff_hdr.add_theme_font_size_override("font_size", UIScale.font_size(16))
		diff_hdr.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
		scores_vbox.add_child(diff_hdr)

		for rank: int in range(entries.size()):
			var e: Dictionary = entries[rank]
			var row_hbox := HBoxContainer.new()
			row_hbox.add_theme_constant_override("separation", 10)
			scores_vbox.add_child(row_hbox)

			var rank_lbl := Label.new()
			rank_lbl.text = "#%d" % (rank + 1)
			rank_lbl.custom_minimum_size = Vector2(UIScale.px(32), 0)
			rank_lbl.add_theme_font_size_override("font_size", UIScale.font_size(14))
			rank_lbl.add_theme_color_override("font_color",
				Color(1.0, 0.85, 0.25) if rank == 0 else SUBTEXT_COLOR)
			row_hbox.add_child(rank_lbl)

			var time_lbl := Label.new()
			time_lbl.text = GameState.format_score_time(e.get("time", 0.0))
			time_lbl.add_theme_font_size_override("font_size", UIScale.font_size(14))
			time_lbl.add_theme_color_override("font_color", TEXT_COLOR)
			time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_hbox.add_child(time_lbl)

			var date_lbl := Label.new()
			date_lbl.text = e.get("date", "")
			date_lbl.add_theme_font_size_override("font_size", UIScale.font_size(13))
			date_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
			row_hbox.add_child(date_lbl)

	if not any_scores:
		var empty_lbl := Label.new()
		empty_lbl.text = "No scores yet – complete a puzzle to get on the board!"
		empty_lbl.add_theme_font_size_override("font_size", UIScale.font_size(15))
		empty_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scores_vbox.add_child(empty_lbl)


# ─── Settings overlay ─────────────────────────────────────────────────────────

## Builds and shows a fullscreen Settings overlay containing:
##   • Difficulty Options  – rotate pieces toggle
##   • Controls            – reference guide for mouse/touch interactions
func _show_settings_overlay() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	add_child(overlay)

	# Dimmed backdrop – clicking it closes the overlay.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				overlay.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.10, 0.22, 0.98)
	_set_corner_radius(ps, 16)
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.55, 0.35, 0.90)
	card.add_theme_stylebox_override("panel", ps)
	card.custom_minimum_size = Vector2(UIScale.px(460), UIScale.px(360))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   UIScale.px(32))
	outer.add_theme_constant_override("margin_right",  UIScale.px(32))
	outer.add_theme_constant_override("margin_top",    UIScale.px(24))
	outer.add_theme_constant_override("margin_bottom", UIScale.px(24))
	card.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)

	# Title row.
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Settings"
	title_lbl.add_theme_font_size_override("font_size", UIScale.font_size(28))
	title_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := _make_button("Close")
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	title_row.add_child(close_btn)

	var sep0 := HSeparator.new()
	sep0.add_theme_color_override("color", Color(0.35, 0.28, 0.55))
	vbox.add_child(sep0)

	# ── Difficulty Options ──────────────────────────────────────────────────────
	var diff_opts_hdr := Label.new()
	diff_opts_hdr.text = "Difficulty Options"
	diff_opts_hdr.add_theme_font_size_override("font_size", UIScale.font_size(18))
	diff_opts_hdr.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
	vbox.add_child(diff_opts_hdr)

	var rot_cb := CheckBox.new()
	rot_cb.text = "Rotate pieces (pieces spawn at random 90° angles – right-click to rotate)"
	rot_cb.button_pressed = GameState.allow_rotation
	rot_cb.add_theme_color_override("font_color", TEXT_COLOR)
	rot_cb.add_theme_font_size_override("font_size", UIScale.font_size(14))
	rot_cb.toggled.connect(func(on: bool) -> void: GameState.allow_rotation = on)
	vbox.add_child(rot_cb)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("color", Color(0.35, 0.28, 0.55))
	vbox.add_child(sep1)

	# ── Controls ───────────────────────────────────────────────────────────────
	var controls_hdr := Label.new()
	controls_hdr.text = "Controls"
	controls_hdr.add_theme_font_size_override("font_size", UIScale.font_size(18))
	controls_hdr.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
	vbox.add_child(controls_hdr)

	var controls: Array[Dictionary] = [
		{"icon": "🖱 Left click",             "desc": "Select a piece"},
		{"icon": "🖱 Hold + drag",            "desc": "Move a piece"},
		{"icon": "🖱 Right click",            "desc": "Rotate piece 90° clockwise (rotation difficulty only)"},
		{"icon": "🖱 Scroll wheel",           "desc": "Zoom in / out"},
		{"icon": "🖱 Middle-click drag",      "desc": "Pan the workspace"},
		{"icon": "👆 Tap & drag",             "desc": "Move a piece (touch)"},
		{"icon": "👐 Pinch",                  "desc": "Zoom in / out (touch)"},
		{"icon": "✌ Two-finger swipe",       "desc": "Pan the workspace (touch)"},
	]

	var controls_vbox := VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(controls_vbox)

	for ctrl: Dictionary in controls:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		controls_vbox.add_child(row)

		var icon_lbl := Label.new()
		icon_lbl.text = ctrl["icon"]
		icon_lbl.custom_minimum_size = Vector2(UIScale.px(180), 0)
		icon_lbl.add_theme_font_size_override("font_size", UIScale.font_size(13))
		icon_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
		row.add_child(icon_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = ctrl["desc"]
		desc_lbl.add_theme_font_size_override("font_size", UIScale.font_size(13))
		desc_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc_lbl)


# ─── Responsive layout ────────────────────────────────────────────────────────

func _on_viewport_size_changed() -> void:
	_update_content_layout()


## Returns true when the viewport is in portrait orientation (taller than wide).
## Delegates to UIScale so there is a single source of truth.
func _is_portrait() -> bool:
	return UIScale.is_portrait()


## Switches the content row between HBoxContainer (landscape) and
## VBoxContainer (portrait) depending on the current viewport aspect ratio.
## Also adjusts the gallery grid column count, button sizes, and margins.
func _update_content_layout() -> void:
	if _content_row == null or _gallery_panel == null or _settings_panel == null:
		return

	var want_portrait := UIScale.is_portrait()
	var is_vbox       := _content_row is VBoxContainer

	# Update outer margins and title regardless of orientation change.
	if _outer_margin != null:
		var sa := UIScale.safe_area_insets()
		_outer_margin.add_theme_constant_override("margin_left",   UIScale.px(40) + int(sa["left"]))
		_outer_margin.add_theme_constant_override("margin_right",  UIScale.px(40) + int(sa["right"]))
		_outer_margin.add_theme_constant_override("margin_top",    UIScale.px(28) + int(sa["top"]))
		_outer_margin.add_theme_constant_override("margin_bottom", UIScale.px(28) + int(sa["bottom"]))

	if _title_lbl != null:
		_title_lbl.add_theme_font_size_override(
			"font_size", UIScale.font_size(36 if want_portrait else 46))
	if _subtitle_lbl != null:
		_subtitle_lbl.visible = not want_portrait

	if want_portrait == is_vbox:
		return  # Container type already matches the current orientation.

	# Build the replacement container.
	var new_row: BoxContainer
	if want_portrait:
		new_row = VBoxContainer.new()
	else:
		new_row = HBoxContainer.new()
	new_row.add_theme_constant_override("separation", UIScale.px(20))
	new_row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Swap the old container for the new one in the scene tree.
	# add_sibling() inserts new_row right after _content_row so that,
	# once the old container is freed, new_row lands at the same index.
	_content_row.add_sibling(new_row)

	# Move the two panels into the new container.
	# keep_global_transform=false is correct: Control position is layout-driven.
	_gallery_panel.reparent(new_row, false)
	_settings_panel.reparent(new_row, false)

	# Free the old (now empty) container.
	_content_row.queue_free()
	_content_row = new_row

	# Adjust thumbnail grid columns.
	if _gallery_grid != null:
		_gallery_grid.columns = 2 if want_portrait else 3

	# Rebuild gallery items so they use the orientation-appropriate touch-target size.
	if _gallery_grid != null:
		for child in _gallery_grid.get_children():
			child.free()
		_gallery_items.clear()
		for i in range(_gallery_textures.size()):
			var item := _build_gallery_item(i)
			_gallery_grid.add_child(item)
			_gallery_items.append(item)
		# Restore the selection highlight on the active item.
		if _active_gallery_idx >= 0 and _active_gallery_idx < _gallery_items.size():
			_set_gallery_item_style(_gallery_items[_active_gallery_idx], true)
