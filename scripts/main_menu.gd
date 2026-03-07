extends Control

# ─── Difficulty presets ───────────────────────────────────────────────────────
const DIFFICULTIES: Array[Dictionary] = [
	{"label": "Easy",   "cols": 3, "rows": 2},
	{"label": "Medium", "cols": 4, "rows": 3},
	{"label": "Hard",   "cols": 6, "rows": 4},
	{"label": "Expert", "cols": 8, "rows": 6},
]

# ─── Built-in gradient palette for the sample gallery ────────────────────────
const GALLERY_DATA := [
	{"name": "Sunset",  "c1": Color(0.18, 0.08, 0.42), "c2": Color(0.98, 0.45, 0.10)},
	{"name": "Ocean",   "c1": Color(0.02, 0.25, 0.55), "c2": Color(0.15, 0.82, 0.88)},
	{"name": "Forest",  "c1": Color(0.03, 0.28, 0.05), "c2": Color(0.35, 0.82, 0.15)},
	{"name": "Dream",   "c1": Color(0.38, 0.02, 0.52), "c2": Color(0.95, 0.25, 0.65)},
	{"name": "Meadow",  "c1": Color(0.70, 0.50, 0.02), "c2": Color(0.25, 0.75, 0.10)},
	{"name": "Dusk",    "c1": Color(0.05, 0.05, 0.25), "c2": Color(0.85, 0.60, 0.90)},
]

# ─── Colour constants ─────────────────────────────────────────────────────────
const BG_COLOR       := Color(0.10, 0.12, 0.17)
const PANEL_COLOR    := Color(0.15, 0.17, 0.22)
const ITEM_COLOR     := Color(0.20, 0.22, 0.30)
const ACCENT_COLOR   := Color(0.55, 0.35, 0.90)
const BTN_COLOR      := Color(0.28, 0.18, 0.52)
const TEXT_COLOR     := Color(0.88, 0.82, 0.98)
const SUBTEXT_COLOR  := Color(0.58, 0.55, 0.68)

# ─── State ────────────────────────────────────────────────────────────────────
var _selected_texture: Texture2D = null
var _selected_path: String       = ""
var _active_gallery_idx: int     = -1
var _difficulty_index: int       = 1

var _gallery_textures: Array[ImageTexture] = []
var _gallery_items: Array[PanelContainer]  = []
var _diff_btns: Array[Button]              = []

var _preview_rect: TextureRect  = null
var _no_image_lbl: Label        = null
var _piece_count_lbl: Label     = null
var _start_btn: Button          = null
var _file_dialog: FileDialog    = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_gallery_textures()
	_build_ui()

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

# ─── Texture generation ───────────────────────────────────────────────────────

func _build_gallery_textures() -> void:
	for data in GALLERY_DATA:
		_gallery_textures.append(
			_create_gradient_texture(data["c1"], data["c2"])
		)


## Creates a 200 × 150 vertical gradient image texture.
func _create_gradient_texture(top: Color, bottom: Color) -> ImageTexture:
	var img := Image.create(200, 150, false, Image.FORMAT_RGBA8)
	for y in range(150):
		var t := float(y) / 149.0
		var col := top.lerp(bottom, t)
		for x in range(200):
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

# ─── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen background.
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer margin.
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left",   40)
	outer.add_theme_constant_override("margin_right",  40)
	outer.add_theme_constant_override("margin_top",    28)
	outer.add_theme_constant_override("margin_bottom", 28)
	add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	outer.add_child(root_vbox)

	root_vbox.add_child(_build_title_section())

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.28, 0.28, 0.40))
	root_vbox.add_child(sep)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 20)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_row)

	content_row.add_child(_build_gallery_panel())
	content_row.add_child(_build_settings_panel())


func _build_title_section() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Puzzle Champ"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Pick an image from the gallery or upload your own, then start your puzzle!"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", SUBTEXT_COLOR)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	return vbox


func _build_gallery_panel() -> Control:
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

	# Thumbnail grid.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	_gallery_items.clear()
	for i in range(_gallery_textures.size()):
		var item := _build_gallery_item(i)
		grid.add_child(item)
		_gallery_items.append(item)

	# Upload button.
	var upload_btn := _make_button("Upload Your Own Image")
	upload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_btn.pressed.connect(_on_upload_pressed)
	vbox.add_child(upload_btn)

	# Bottom spacer so upload stays near the thumbnails.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	return panel


func _build_gallery_item(index: int) -> PanelContainer:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(112, 84)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_gallery_item_style(container, false)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   3)
	inner.add_theme_constant_override("margin_right",  3)
	inner.add_theme_constant_override("margin_top",    3)
	inner.add_theme_constant_override("margin_bottom", 3)
	container.add_child(inner)

	var tex_rect := TextureRect.new()
	tex_rect.texture      = _gallery_textures[index]
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
	btn.add_theme_font_size_override("font_size", 16)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = BTN_COLOR
			"hover":   sb.bg_color = BTN_COLOR.lightened(0.20)
			"pressed": sb.bg_color = BTN_COLOR.darkened(0.15)
		_set_corner_radius(sb, 8)
		sb.content_margin_left   = 14
		sb.content_margin_right  = 14
		sb.content_margin_top    = 10
		sb.content_margin_bottom = 10
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
	_apply_selection(_gallery_textures[index], "", index)


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
	_apply_selection(ImageTexture.create_from_image(img), path, -1)


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
	get_tree().change_scene_to_file("res://scenes/puzzle_board.tscn")


func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title       = "Oops"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
