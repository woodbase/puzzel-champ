extends Control

# ─── Difficulty presets ───────────────────────────────────────────────────────
const DIFFICULTIES: Array[Dictionary] = [
	{"label": "Easy",   "cols": 3, "rows": 2},
	{"label": "Medium", "cols": 4, "rows": 3},
	{"label": "Hard",   "cols": 6, "rows": 4},
	{"label": "Expert", "cols": 8, "rows": 6},
]

# ─── Piece shape presets ──────────────────────────────────────────────────────
const SHAPES: Array[Dictionary] = [
	{"label": "Square", "key": "square"},
	{"label": "Jigsaw", "key": "jigsaw"},
]

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
var _start_btn: Button           = null
var _file_dialog: FileDialog     = null
var _gallery_grid: GridContainer = null  # kept for dynamic item insertion
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

	_apply_difficulty(
		_find_difficulty_index(GameState.cols, GameState.rows)
	)

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


## Copies an image file into user://gallery/ and returns the user:// path.
## Returns "" on failure.  A unique filename is chosen if one already exists.
func _save_user_image(src_path: String) -> String:
	# Ensure the directory exists.
	var abs_dir := ProjectSettings.globalize_path(USER_GALLERY_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	var filename := src_path.get_file()
	var dest_path := USER_GALLERY_DIR + filename
	# Avoid overwriting an existing file.
	var counter := 1
	while FileAccess.file_exists(dest_path):
		dest_path = USER_GALLERY_DIR + "%s_%d.%s" % [
			filename.get_basename(), counter, filename.get_extension()
		]
		counter += 1

	var data := FileAccess.get_file_as_bytes(src_path)
	if data.is_empty():
		return ""
	var f := FileAccess.open(dest_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(data)
	f.close()
	return dest_path


## Returns a THUMBNAIL_SIZE × THUMBNAIL_SIZE ImageTexture scaled from *img*.
## The original Image object is not modified.
func _make_thumbnail(img: Image) -> ImageTexture:
	var copy := img.duplicate() as Image
	copy.resize(THUMBNAIL_SIZE, THUMBNAIL_SIZE, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(copy)

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
	_outer_margin.add_theme_constant_override("margin_left",   UIScale.px(40))
	_outer_margin.add_theme_constant_override("margin_right",  UIScale.px(40))
	_outer_margin.add_theme_constant_override("margin_top",    UIScale.px(28))
	_outer_margin.add_theme_constant_override("margin_bottom", UIScale.px(28))
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

	_piece_count_lbl = Label.new()
	_piece_count_lbl.add_theme_font_size_override("font_size", 14)
	_piece_count_lbl.add_theme_color_override("font_color", SUBTEXT_COLOR)
	vbox.add_child(_piece_count_lbl)

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


func _make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
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


func _find_difficulty_index(c: int, r: int) -> int:
	for i in range(DIFFICULTIES.size()):
		if DIFFICULTIES[i]["cols"] == c and DIFFICULTIES[i]["rows"] == r:
			return i
	return 1  # default: Medium


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

	# Save the image to user://gallery/ so it is available in future sessions.
	var saved_path := _save_user_image(path)
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


func _on_start_pressed() -> void:
	if _selected_texture == null:
		_show_error("Please select an image first.")
		return
	var d := DIFFICULTIES[_difficulty_index]
	GameState.image_texture = _selected_texture
	GameState.image_path    = _selected_path
	GameState.gallery_index = _active_gallery_idx
	GameState.cols          = d["cols"]
	GameState.rows          = d["rows"]
	GameState.piece_shape   = SHAPES[_shape_index]["key"]
	get_tree().change_scene_to_file("res://scenes/puzzle_board.tscn")


func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title       = "Oops"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


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
		_outer_margin.add_theme_constant_override("margin_left",   UIScale.px(40))
		_outer_margin.add_theme_constant_override("margin_right",  UIScale.px(40))
		_outer_margin.add_theme_constant_override("margin_top",    UIScale.px(28))
		_outer_margin.add_theme_constant_override("margin_bottom", UIScale.px(28))

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
