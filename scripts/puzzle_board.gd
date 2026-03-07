extends Node2D

## Source image (editor-assigned fallback; GameState takes priority at runtime).
@export var source_texture: Texture2D

## Grid columns (editor fallback; overridden by GameState at runtime).
@export var cols: int = 4

## Grid rows (editor fallback; overridden by GameState at runtime).
@export var rows: int = 3

## CanvasLayer that holds all HUD elements.
@onready var _hud: CanvasLayer = $HUD

## PuzzlePiece scene instantiated for each piece.
const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")

## PuzzleGenerator script used to build the puzzle.
const PuzzleGeneratorScript = preload("res://scripts/puzzle_generator.gd")

## Height in pixels of the top HUD bar.
const HUD_H: float = 52.0

## Total number of puzzle pieces managed by this board.
var _total_pieces: int = 0

## Number of pieces that have been snapped into place.
var _placed_pieces: int = 0

## Generator instance.
var _generator: PuzzleGeneratorScript = null

## HUD label showing piece progress.
var _counter_label: Label = null

## Fullscreen overlay shown when the puzzle is complete.
var _complete_overlay: Control = null

## Guard flag: prevents overlapping rebuild calls.
var _building: bool = false


func _ready() -> void:
	_generator = PuzzleGeneratorScript.new()

	# GameState overrides the editor export vars when coming from the menu.
	if GameState.image_texture != null:
		source_texture = GameState.image_texture
		cols           = GameState.cols
		rows           = GameState.rows

	_build_hud()

	if source_texture != null:
		_build_puzzle()
	else:
		_show_no_image_message()


# ─── HUD construction ─────────────────────────────────────────────────────────

func _build_hud() -> void:
	# Semi-transparent top bar.
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.10, 0.12, 0.17, 0.92)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = HUD_H
	_hud.add_child(top_bar)

	# Button / counter row.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hbox.offset_left   = 12
	hbox.offset_right  = -12
	hbox.offset_bottom = HUD_H
	hbox.add_theme_constant_override("separation", 8)
	_hud.add_child(hbox)

	var back_btn := _make_hud_button("Menu")
	back_btn.pressed.connect(_on_back_pressed)
	hbox.add_child(back_btn)

	var new_btn := _make_hud_button("New Puzzle")
	new_btn.pressed.connect(_on_new_puzzle)
	hbox.add_child(new_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 18)
	_counter_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter_label.custom_minimum_size = Vector2(0, HUD_H)
	hbox.add_child(_counter_label)

	_update_counter()
	_build_complete_overlay()


func _make_hud_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	btn.add_theme_font_size_override("font_size", 16)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = Color(0.28, 0.18, 0.52)
			"hover":   sb.bg_color = Color(0.38, 0.25, 0.65)
			"pressed": sb.bg_color = Color(0.20, 0.12, 0.40)
		sb.corner_radius_top_left     = 6
		sb.corner_radius_top_right    = 6
		sb.corner_radius_bottom_left  = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left   = 12
		sb.content_margin_right  = 12
		sb.content_margin_top    = 8
		sb.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, sb)

	return btn


func _build_complete_overlay() -> void:
	_complete_overlay = Control.new()
	_complete_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.visible = false
	_hud.add_child(_complete_overlay)

	# Dimmed backdrop.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.add_child(dim)

	# Centred card.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.add_child(center)

	var card := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.12, 0.25)
	ps.corner_radius_top_left     = 16
	ps.corner_radius_top_right    = 16
	ps.corner_radius_bottom_left  = 16
	ps.corner_radius_bottom_right = 16
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.55, 0.35, 0.90)
	card.add_theme_stylebox_override("panel", ps)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   48)
	margin.add_theme_constant_override("margin_right",  48)
	margin.add_theme_constant_override("margin_top",    36)
	margin.add_theme_constant_override("margin_bottom", 36)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var emoji_lbl := Label.new()
	emoji_lbl.text = "Puzzle Complete!"
	emoji_lbl.add_theme_font_size_override("font_size", 40)
	emoji_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Well done – all pieces placed!"
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.80))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var menu_btn := _make_hud_button("Back to Menu")
	menu_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(menu_btn)

	var new_btn := _make_hud_button("New Puzzle")
	new_btn.pressed.connect(_on_new_puzzle)
	btn_row.add_child(new_btn)


## Shows a message when no image is available (e.g. scene run from the editor).
func _show_no_image_message() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.17)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "No image selected.\nGo back to the menu and choose an image."
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var btn := _make_hud_button("Back to Menu")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_back_pressed)
	vbox.add_child(btn)


# ─── Puzzle building ──────────────────────────────────────────────────────────

## Builds the puzzle dynamically from source_texture using PuzzleGenerator.
## Steps: load image → calculate piece_size → generate_edges → for each
## PieceData generate polygon + texture + instantiate PuzzlePiece scene.
## Each piece stores its correct world position; pieces spawn randomly
## below the HUD bar.
func _build_puzzle() -> void:
	if cols < 1 or rows < 1:
		push_error("PuzzleBoard: cols and rows must each be at least 1 (got cols=%d, rows=%d)." % [cols, rows])
		return

	var image := source_texture.get_image()
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var img_w := image.get_width()
	var img_h := image.get_height()

	# Calculate piece size (square pieces using the smaller cell dimension).
	var piece_size: int = min(img_w / cols, img_h / rows)

	var piece_data_array := _generator.generate_edges(cols, rows)
	_total_pieces  = piece_data_array.size()
	_placed_pieces = 0
	_update_counter()

	var viewport_size := get_viewport_rect().size

	for pd in piece_data_array:
		var col: int = pd.grid_pos.x
		var row: int = pd.grid_pos.y

		# Generate jigsaw polygon and masked texture for this piece.
		var polygon := _generator.generate_piece_polygon(pd, piece_size)
		var region  := Rect2i(col * piece_size, row * piece_size, piece_size, piece_size)
		var texture := _generator.create_piece_texture(image, region, polygon)

		# Correct world position is the centre of the grid cell.
		var correct_pos := Vector2(
			(col + 0.5) * piece_size,
			(row + 0.5) * piece_size
		)

		var piece := PIECE_SCENE.instantiate()
		add_child(piece)

		var sprite    := piece.get_node("Sprite2D") as Sprite2D
		sprite.texture = texture

		# Give each piece its own collision shape sized to the piece.
		var col_shape  := piece.get_node("CollisionShape2D") as CollisionShape2D
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(piece_size, piece_size)
		col_shape.shape = rect_shape

		piece.correct_position = correct_pos

		# Spawn randomly; keep pieces below the HUD bar.
		var half := piece_size * 0.5
		piece.position = Vector2(
			randf_range(half, viewport_size.x - half),
			randf_range(HUD_H + half, viewport_size.y - half)
		)
		piece.piece_placed.connect(on_piece_placed)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _update_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "Pieces: %d / %d" % [_placed_pieces, _total_pieces]


## Called by each PuzzlePiece when it snaps into place.
func on_piece_placed() -> void:
	_placed_pieces += 1
	_update_counter()
	if _placed_pieces >= _total_pieces and _total_pieces > 0:
		_show_complete()


## Displays the completion overlay.
func _show_complete() -> void:
	if _complete_overlay != null:
		_complete_overlay.visible = true


## Returns to the main menu.
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Clears all pieces and rebuilds the puzzle with the same image.
func _on_new_puzzle() -> void:
	if _building:
		return
	_building = true

	if _complete_overlay != null:
		_complete_overlay.visible = false

	for piece in get_tree().get_nodes_in_group("puzzle_pieces"):
		piece.queue_free()

	_placed_pieces = 0
	_total_pieces  = 0
	_update_counter()

	# Wait one frame so queue_free calls have resolved before rebuilding.
	await get_tree().process_frame
	_build_puzzle()
	_building = false
