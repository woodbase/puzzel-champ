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

## Confetti celebration effect played on puzzle completion.
const ConfettiEffect = preload("res://scripts/confetti_effect.gd")

## Puzzle border glow effect played on puzzle completion.
const PuzzleGlowEffect = preload("res://scripts/puzzle_glow_effect.gd")
## Main menu script – used as the single source of difficulty presets so that
## puzzle_board.gd stays in sync with main_menu.gd without duplicating data.
const MainMenuScript = preload("res://scripts/main_menu.gd")

# ─── UI icon assets ───────────────────────────────────────────────────────────
const ICON_MENU     := preload("res://gfx/ui/icons/icon_menu.png")
const ICON_SAVE     := preload("res://gfx/ui/icons/icon_save.png")
const ICON_TROPHY   := preload("res://gfx/ui/icons/icon_trophy.png")
const ICON_SETTINGS := preload("res://gfx/ui/icons/icon_settings.png")

## Height in pixels of the top HUD bar. Set dynamically based on
## orientation and screen scale so that portrait / mobile gets a taller bar
## with comfortably large touch targets.
var HUD_H: float = 52.0

## Total number of puzzle pieces managed by this board.
var _total_pieces: int = 0

## Number of pieces that have been snapped into place.
var _placed_pieces: int = 0

## Generator instance.
var _generator: Object = null

## HUD label showing piece progress.
var _counter_label: Label = null

## HUD label showing elapsed puzzle time.
var _timer_label: Label = null

## Accumulated elapsed time in seconds since the current puzzle began.
var _timer_elapsed: float = 0.0

## True while the puzzle timer is counting up (puzzle in progress).
var _timer_running: bool = false

## Last whole-second value shown in the timer label; used to avoid redundant
## label updates every frame when the displayed value has not changed.
var _timer_last_s: int = -1

## Label inside the completion card that shows the final solve time.
var _complete_time_lbl: Label = null

## Fullscreen overlay shown when the puzzle is complete.
var _complete_overlay: Control = null

## The completion card panel inside _complete_overlay.
## Stored so the card entrance animation can target it.
var _complete_card: Control = null

## Fullscreen leaderboard overlay shown from the completion card or HUD menu.
var _leaderboard_overlay: Control = null

## Confetti particle effect shown on puzzle completion.
var _confetti: Object = null

## Pulsing border glow shown around the puzzle on completion.
var _glow_effect: Object = null

## Guard flag: prevents overlapping rebuild calls.
var _building: bool = false

## Currently selected piece shape key (mirrors GameState.piece_shape).
var _piece_shape: String = "jigsaw"

## Screen-space size of each puzzle piece cell (width × height).
## Preserved as a Vector2 so non-square images can be displayed without
## distortion; x = width per column, y = height per row.
var _piece_size: Vector2 = Vector2.ZERO

## Top-left corner of the puzzle grid in board-local coordinates.
## Used to centre the board on screen and kept so derived calculations
## (glow effect, celebration wave) remain correct after layout changes.
var _puzzle_origin: Vector2 = Vector2.ZERO

## The piece currently being dragged, or null when nothing is held.
var _dragged_piece = null

## Last recorded global position of the dragged piece.
## Used to skip queue_redraw() calls when the piece has not moved, avoiding
## redundant canvas redraws every frame while the player holds a piece still.
var _last_drag_pos: Vector2 = Vector2.ZERO

## All puzzle pieces created during the last _build_puzzle() call.
## Kept so the board entry animation can target each piece individually.
var _pieces: Array = []

## Initial spawn positions recorded for each piece during _build_puzzle().
## Used by _on_restart_puzzle() to return pieces to their starting positions.
var _pieces_initial_positions: Array[Vector2] = []

## Full-screen dark overlay used for the puzzle-image fade-in animation.
## Freed automatically once the fade-out completes.
var _entry_overlay: ColorRect = null

## AudioStreamPlayer used to play the pickup sound effect.
var _pickup_player: AudioStreamPlayer = null

## AudioStreamPlayer used to play the snap sound effect.
var _snap_player: AudioStreamPlayer = null

## AudioStreamPlayer used to play the puzzle-completion fanfare.
var _complete_player: AudioStreamPlayer = null

## AudioStreamPlayer used to play the background music.
var _music_player: AudioStreamPlayer = null

## The settings panel overlay (visibility toggled by the settings button).
var _settings_panel: Control = null

## Floating reference image panel anchored to the top-left corner of the screen.
## Visible by default; toggled with the HUD "Preview" button.
var _preview_panel: Control = null

## Full-screen zoom overlay shown when the player clicks the reference panel.
## Dismissed by clicking anywhere on the overlay backdrop.
var _zoom_overlay: Control = null

## Preview toggle button stored so its label can be updated.
var _preview_toggle_btn: Button = null

## Difficulty buttons inside the in-game menu panel.
var _menu_diff_btns: Array[Button] = []

## ColorRect that forms the HUD top bar; stored to allow height updates on
## orientation / scale change.
var _hud_top_bar: ColorRect = null

## HBoxContainer that holds the HUD buttons and counter; stored to allow
## height and layout updates on orientation / scale change.
var _hud_hbox: HBoxContainer = null

## All buttons created inside the HUD bar, stored so their styles can be
## refreshed when the layout changes.
var _hud_buttons: Array[Button] = []

## The right-side "Menu" button in the HUD bar, stored separately so its
## width component of custom_minimum_size can be updated when HUD_H changes.
var _hud_menu_btn: Button = null

## Sorting-box data list.  Each element is a Dictionary with keys:
##   "name"   – display label (String)
##   "pieces" – piece nodes currently stored in this box (Array)
##   "button" – the Button node in the left panel (Button)
var _sorting_boxes: Array = []

## Panel containing sorting-box buttons on the left side below the reference image.
var _box_panel: Control = null

## VBoxContainer inside the sorting-box panel that holds the box buttons.
var _box_vbox: VBoxContainer = null

## Full-screen overlay shown when the player opens a sorting box to view its pieces.
var _box_view_overlay: Control = null

## GridContainer inside the box-view overlay that holds piece thumbnails.
var _box_view_grid: GridContainer = null

## Title label inside the box-view overlay.
var _box_view_title: Label = null

## Index of the sorting box currently displayed in the view overlay (-1 = none).
var _open_box_index: int = -1

## Index of the sorting box whose button is highlighted as a drop target while
## the player is dragging a piece (-1 = none highlighted).
var _drag_highlight_box_idx: int = -1

## Floating popup shown when hovering a sorting-box button to preview stored pieces.
var _box_hover_popup: Control = null

## GridContainer inside the hover-preview popup that holds piece thumbnails.
var _box_hover_popup_grid: GridContainer = null

## Tracks the portrait/landscape state from the last layout update.
## Used to detect orientation flips and trigger a puzzle rebuild so pieces
## always fit the newly-rotated screen.
var _last_portrait: bool = false

## Bottom panel containing controls, reference image, and sorting boxes.
var _bottom_panel: Control = null

## Toggle button in the top bar that hides/shows the bottom panel to expand
## the puzzle workspace (mobile only).
var _bottom_panel_toggle_btn: Button = null

## Whether the bottom panel is currently visible (workspace in normal mode).
## When false the bottom panel is hidden and the full screen is puzzle workspace.
var _bottom_panel_expanded: bool = true

## Height of the bottom panel when expanded.
const BOTTOM_PANEL_HEIGHT_PORTRAIT: float = 240.0
const BOTTOM_PANEL_HEIGHT_LANDSCAPE: float = 180.0

## Camera2D that controls the puzzle workspace zoom and pan.
var _camera: Camera2D = null

## Current zoom level (1.0 = default, >1 = zoomed in, <1 = zoomed out).
var _zoom_level: float = 1.0

## Minimum zoom level – the workspace can be shrunk to half its default size.
const ZOOM_MIN: float = 0.5

## Maximum zoom level – the workspace can be enlarged to four times its default size.
const ZOOM_MAX: float = 4.0

## Multiplicative step applied per mouse-wheel tick (≈ 15 % per tick).
const ZOOM_STEP: float = 1.15

## True while the workspace is being panned via middle-mouse drag.
var _panning: bool = false

## Mouse screen position recorded when the current pan gesture started.
var _pan_start_mouse: Vector2 = Vector2.ZERO

## Camera world position recorded when the current pan gesture started.
var _pan_start_cam: Vector2 = Vector2.ZERO

## Base volume_db values for each AudioStreamPlayer (before volume scaling).
const PICKUP_BASE_DB: float = -10.0
const SNAP_BASE_DB: float = -6.0
const COMPLETE_BASE_DB: float = -3.0
const MUSIC_BASE_DB: float = -18.0

## Path to the single save-slot file (mirrors GameState.SAVE_PATH for convenience).
const SAVE_PATH: String = "user://puzzle_save.json"

## Small HUD label that shows the save-slot status ("Saved" or nothing).
var _save_slot_label: Label = null

## Minimum linear volume passed to linear_to_db() to avoid log(0) errors.
const MIN_VOLUME_LINEAR: float = 0.0001

## Background colour of the board entry fade-in overlay.
const ENTRY_OVERLAY_COLOR := Color(0.05, 0.05, 0.10, 1.0)

## Font colour for the workspace-expand toggle button when the bottom panel is
## visible (normal state) and when the workspace is expanded (panel hidden).
const HUD_BTN_NORMAL_COLOR   := Color(0.88, 0.82, 0.98)
const HUD_BTN_ACTIVE_COLOR   := Color(0.55, 0.85, 0.55)

## Time in seconds between each piece's scale-in animation during board entry.
## Enhanced with accelerating stagger for smoother flow.
const PIECE_STAGGER_DELAY: float = 0.025

## Width and height of the reference image thumbnail panel.
const REFERENCE_PANEL_W: float = 160.0
const REFERENCE_PANEL_H: float = 120.0
## Gap between the reference panel and the screen / HUD edges.
const REFERENCE_PANEL_MARGIN: float = 8.0
## Source image pieces are downscaled to at most 1.35 × the on-screen piece size
## so GPU memory / bandwidth stay reasonable on mobile while keeping detail.
const SOURCE_OVERSAMPLE: float = 1.35

## Predefined sorting-box category names shown to the player by default.
const SORTING_BOX_DEFAULTS: Array[String] = ["Edge Pieces", "Sky", "Buildings", "Other"]

## Width of the sorting-box panel (matches the reference panel for visual consistency).
const BOX_PANEL_W: float = 160.0

## Vertical gap between the bottom of the reference panel and the top of the sorting panel.
const BOX_PANEL_TOP_GAP: float = 4.0

## Height of each individual box-entry button in the panel.
const BOX_BUTTON_H: float = 34.0


func _ready() -> void:
	# Set HUD bar height based on orientation, screen scale, and safe area.
	# The safe area top inset (notch / status bar) is folded into HUD_H so the
	# top bar always covers the full inset and the puzzle canvas starts below it.
	var safe_insets := UIScale.safe_area_insets()
	HUD_H = UIScale.px(64.0 if UIScale.is_portrait() else 52.0) + safe_insets["top"]
	_last_portrait = UIScale.is_portrait()

	_generator = PuzzleGeneratorScript.new()
	_pickup_player = _create_pickup_audio_player()
	add_child(_pickup_player)
	_snap_player = _create_snap_audio_player()
	add_child(_snap_player)
	_complete_player = _create_complete_audio_player()
	add_child(_complete_player)
	_music_player = _create_music_player()
	add_child(_music_player)
	_apply_volume()

	# Camera2D for workspace zoom and pan.
	_camera = Camera2D.new()
	add_child(_camera)

	# Keep HUD in sync when the window is resized or the device rotates.
	UIScale.layout_changed.connect(_on_layout_changed)

	# GameState overrides the editor export vars when coming from the menu.
	if GameState.image_texture != null:
		source_texture = GameState.image_texture
		cols           = GameState.cols
		rows           = GameState.rows
		_piece_shape   = GameState.piece_shape

	_build_hud()

	if source_texture != null:
		_build_puzzle()
		if GameState.resume_save:
			GameState.resume_save = false
			_apply_saved_state()
	else:
		_show_no_image_message()

	if GameState.music_enabled:
		_music_player.play()


func _process(delta: float) -> void:
	if _timer_running:
		_timer_elapsed += delta
		var current_s: int = int(_timer_elapsed)
		if current_s != _timer_last_s:
			_timer_last_s = current_s
			_update_timer_label()
	if _dragged_piece != null and GameState.feedback_visual and GameState.snap_to_board:
		var current_pos: Vector2 = _dragged_piece.global_position
		if current_pos != _last_drag_pos:
			_last_drag_pos = current_pos
			queue_redraw()
	if _dragged_piece != null:
		_update_box_drop_highlight()


## Draws a highlight rectangle at the target position of the dragged piece when
## it is within HIGHLIGHT_DISTANCE of that target.
func _draw() -> void:
	if _dragged_piece == null or not GameState.feedback_visual or not GameState.snap_to_board or _piece_size == Vector2.ZERO:
		return
	var target_local: Vector2 = _dragged_piece.correct_position
	var target_global: Vector2 = to_global(target_local)
	var dist: float = _dragged_piece.global_position.distance_to(target_global)
	# Highlight radius is 50 % of the shorter piece side, which is always larger
	# than the 35 % snap threshold so the green glow appears before locking.
	var highlight_distance: float = minf(_piece_size.x, _piece_size.y) * 0.5
	if dist >= highlight_distance:
		return
	# Alpha increases as the piece approaches the target (0 at edge → 1 at centre).
	var alpha: float = 1.0 - (dist / highlight_distance)
	var half: Vector2 = _piece_size * 0.5
	var rect := Rect2(target_local - half, _piece_size)
	draw_rect(rect, Color(0.2, 0.85, 0.2, alpha * 0.25), true)
	draw_rect(rect, Color(0.2, 0.95, 0.2, alpha * 0.80), false)


# ─── HUD construction ─────────────────────────────────────────────────────────

## Returns true when the viewport is in portrait orientation (taller than wide).
## Delegates to UIScale so there is a single source of truth.
func _is_portrait() -> bool:
	return UIScale.is_portrait()


## Returns the height of the bottom panel based on orientation.
func _get_bottom_panel_height() -> float:
	var base_height := BOTTOM_PANEL_HEIGHT_PORTRAIT if UIScale.is_portrait() else BOTTOM_PANEL_HEIGHT_LANDSCAPE
	return UIScale.px(base_height)


## Returns the effective space reserved at the bottom of the canvas, which
## is the panel height plus the safe area bottom inset (gesture strip / home
## indicator).  Used for puzzle layout calculations so pieces never spawn or
## sit behind the bottom UI or the system gesture area.
func _get_bottom_reserved_height() -> float:
	return _get_bottom_panel_height() + UIScale.safe_area_insets()["bottom"]


func _build_hud() -> void:
	# Semi-transparent top bar – reference stored for layout updates.
	_hud_top_bar = ColorRect.new()
	_hud_top_bar.color = Color(0.10, 0.12, 0.17, 0.95)
	_hud_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_top_bar.offset_bottom = HUD_H
	_hud.add_child(_hud_top_bar)

	# Button / counter row – reference stored for layout updates.
	_hud_hbox = HBoxContainer.new()
	_hud_hbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var safe_insets := UIScale.safe_area_insets()
	_hud_hbox.offset_top    = safe_insets["top"]
	_hud_hbox.offset_left   = 8 + safe_insets["left"]
	_hud_hbox.offset_right  = -8 - safe_insets["right"]
	_hud_hbox.offset_bottom = HUD_H
	_hud_hbox.add_theme_constant_override("separation", UIScale.px(16 if UIScale.is_mobile() else 12))
	_hud.add_child(_hud_hbox)

	_hud_buttons.clear()

	# Left side: Back button
	var back_btn := _make_hud_button("← Back")
	back_btn.pressed.connect(_on_back_pressed)
	_hud_hbox.add_child(back_btn)
	_hud_buttons.append(back_btn)

	# Center: Title and info
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 0)
	_hud_hbox.add_child(center_vbox)

	var title_label := Label.new()
	title_label.text = "Puzzle Challenge"
	title_label.add_theme_font_size_override("font_size", UIScale.font_size(16))
	title_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_vbox.add_child(title_label)

	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 16)
	center_vbox.add_child(info_hbox)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", UIScale.font_size(13))
	_timer_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_hbox.add_child(_timer_label)

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", UIScale.font_size(13))
	_counter_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.85))
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_hbox.add_child(_counter_label)

	# Expand workspace toggle – mobile only.  Hides the bottom panel so the
	# full screen is available for puzzle solving.
	if UIScale.is_mobile():
		_bottom_panel_toggle_btn = _make_hud_button("▼")
		_bottom_panel_toggle_btn.tooltip_text = "Expand workspace"
		_bottom_panel_toggle_btn.custom_minimum_size = Vector2(UIScale.px(48), UIScale.px(48))
		_bottom_panel_toggle_btn.pressed.connect(_toggle_workspace_expand)
		_hud_hbox.add_child(_bottom_panel_toggle_btn)
		_hud_buttons.append(_bottom_panel_toggle_btn)

	var settings_btn := _make_hud_button("Menu")
	settings_btn.icon = ICON_MENU
	settings_btn.pressed.connect(_toggle_settings_panel)
	settings_btn.tooltip_text = "Game menu"
	settings_btn.custom_minimum_size = Vector2(HUD_H - 8, UIScale.px(48))
	_hud_hbox.add_child(settings_btn)
	_hud_buttons.append(settings_btn)
	_hud_menu_btn = settings_btn

	_save_slot_label = Label.new()
	_save_slot_label.add_theme_font_size_override("font_size", UIScale.font_size(12))
	_save_slot_label.add_theme_color_override("font_color", Color(0.60, 0.85, 0.65))
	_save_slot_label.visible = false

	_update_counter()
	_build_settings_panel()
	_build_complete_overlay()
	_build_bottom_panel()


func _make_hud_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	var portrait := UIScale.is_portrait()
	btn.add_theme_font_size_override("font_size", UIScale.font_size(18 if portrait else 16))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(0, UIScale.px(48))

	var padding_v := UIScale.px(12.0 if portrait else 8.0)
	var padding_h := UIScale.px(16.0 if portrait else 12.0)
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
		sb.content_margin_left   = padding_h
		sb.content_margin_right  = padding_h
		sb.content_margin_top    = padding_v
		sb.content_margin_bottom = padding_v
		btn.add_theme_stylebox_override(state, sb)

	return btn


## Updates the HUD bar height and button styles to match the current layout.
## Called when UIScale emits layout_changed (orientation flip or window resize).
func _on_layout_changed() -> void:
	var safe := UIScale.safe_area_insets()
	HUD_H = UIScale.px(64.0 if UIScale.is_portrait() else 52.0) + safe["top"]

	if _hud_top_bar != null:
		_hud_top_bar.offset_bottom = HUD_H

	if _hud_hbox != null:
		_hud_hbox.offset_top    = safe["top"]
		_hud_hbox.offset_left   = 8 + safe["left"]
		_hud_hbox.offset_right  = -8 - safe["right"]
		_hud_hbox.offset_bottom = HUD_H
		_hud_hbox.add_theme_constant_override("separation", UIScale.px(16 if UIScale.is_mobile() else 12))

	if _counter_label != null:
		_counter_label.add_theme_font_size_override("font_size", UIScale.font_size(13))

	if _save_slot_label != null:
		_save_slot_label.add_theme_font_size_override("font_size", UIScale.font_size(12))

	if _timer_label != null:
		_timer_label.add_theme_font_size_override("font_size", UIScale.font_size(13))

	var portrait := UIScale.is_portrait()
	var padding_v := UIScale.px(12.0 if portrait else 8.0)
	var padding_h := UIScale.px(16.0 if portrait else 12.0)
	var min_h: int = UIScale.px(48)
	for btn in _hud_buttons:
		btn.add_theme_font_size_override(
			"font_size", UIScale.font_size(18 if portrait else 16))
		btn.custom_minimum_size = Vector2(btn.custom_minimum_size.x, min_h)
		for state in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = btn.get_theme_stylebox(state) as StyleBoxFlat
			if sb != null:
				sb.content_margin_left   = padding_h
				sb.content_margin_right  = padding_h
				sb.content_margin_top    = padding_v
				sb.content_margin_bottom = padding_v

	# Keep the Menu button wide enough to comfortably display its icon + text
	# and preserve the 48px touch-target height set above.
	if _hud_menu_btn != null:
		_hud_menu_btn.custom_minimum_size = Vector2(HUD_H - 8, min_h)

	# Reposition the settings panel below the (possibly resized) HUD bar.
	if _settings_panel != null:
		_settings_panel.offset_top    = HUD_H + 4
		_settings_panel.offset_bottom = HUD_H + 4 + _settings_panel_height()

	# Reposition the bottom panel at the bottom of the screen, above the safe area.
	if _bottom_panel != null:
		var panel_h := _get_bottom_panel_height()
		var safe_bottom := safe["bottom"]
		_bottom_panel.offset_top    = -(panel_h + safe_bottom)
		_bottom_panel.offset_bottom = -safe_bottom

	# Rebuild the puzzle when the device orientation flips (portrait ↔ landscape)
	# so that all piece positions and the grid layout fit the new screen dimensions.
	if portrait != _last_portrait:
		_last_portrait = portrait
		if not _pieces.is_empty() and not _building:
			_on_new_puzzle()


## Returns the pixel height the settings/menu panel should have.
## Caps at the available viewport height below the HUD so the panel never
## overflows the screen (important on small landscape phone screens).
func _settings_panel_height() -> int:
	var vp_h := int(get_viewport().get_visible_rect().size.y)
	# 460 px is the natural content height; cap to fit on small screens.
	return mini(460, vp_h - int(HUD_H) - 8)


# ─── Workspace zoom and pan ───────────────────────────────────────────────────

## Resets the workspace camera to the default 1:1 zoom centred on the viewport.
## Also clears any in-progress pan gesture.
func _reset_camera() -> void:
	if _camera == null:
		return
	_zoom_level = 1.0
	_panning = false
	_camera.zoom = Vector2.ONE
	_camera.position = get_viewport_rect().size * 0.5


## Zooms the workspace by zoom_factor, keeping the world point under
## screen_pos visually fixed (zoom-to-cursor behaviour).
## zoom_factor > 1 zooms in; zoom_factor < 1 zooms out.
func _zoom_at_point(zoom_factor: float, screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var old_zoom := _zoom_level
	_zoom_level = clampf(_zoom_level * zoom_factor, ZOOM_MIN, ZOOM_MAX)
	if _zoom_level == old_zoom:
		return  # Already at the limit; nothing to do.
	var vp_center := get_viewport_rect().size * 0.5
	# Shift the camera so the world point under screen_pos stays fixed.
	# Derivation: world_pt = (screen_pos - vp_center) / zoom + cam_pos (same before and after).
	_camera.position += (screen_pos - vp_center) * (1.0 / old_zoom - 1.0 / _zoom_level)
	_camera.zoom = Vector2(_zoom_level, _zoom_level)


## Handles workspace zoom and pan input.
## Piece-drag events (left mouse button) are consumed by each PuzzlePiece before
## reaching _unhandled_input, so zoom and pan never interfere with piece dragging.
##
## Controls:
##   Mouse wheel up/down  – zoom in / out toward the cursor
##   Middle-mouse drag    – pan the workspace (grab-and-drag)
##   Pinch gesture        – zoom in / out (trackpad and touch screen)
##   Two-finger pan       – pan the workspace (trackpad and touch screen)
func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_at_point(ZOOM_STEP, mb.position)
					get_viewport().set_input_as_handled()
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_at_point(1.0 / ZOOM_STEP, mb.position)
					get_viewport().set_input_as_handled()
				MOUSE_BUTTON_MIDDLE:
					_panning = true
					_pan_start_mouse = mb.position
					_pan_start_cam   = _camera.position
					get_viewport().set_input_as_handled()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _panning:
		var mm := event as InputEventMouseMotion
		# Divide by zoom so the pan speed matches the visual size of objects.
		_camera.position = _pan_start_cam - (mm.position - _pan_start_mouse) / _zoom_level
		get_viewport().set_input_as_handled()

	elif event is InputEventMagnifyGesture:
		# Pinch-to-zoom on touch screens and trackpads.
		var mg := event as InputEventMagnifyGesture
		_zoom_at_point(mg.factor, mg.position)
		get_viewport().set_input_as_handled()

	elif event is InputEventPanGesture:
		# Two-finger scroll/swipe on trackpads and touch screens.
		var pg := event as InputEventPanGesture
		_camera.position += pg.delta / _zoom_level
		get_viewport().set_input_as_handled()


## Builds a floating game-menu panel anchored below the HUD bar.
## The panel includes: difficulty selector, audio/visual settings toggles,
## and a volume slider – serving as the game's in-play menu.
## A ScrollContainer is used so all items remain reachable on small screens
## (e.g. a phone in landscape where the panel height is viewport-constrained).
func _build_settings_panel() -> void:
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.10, 0.22, 0.96)
	ps.corner_radius_top_left     = 8
	ps.corner_radius_top_right    = 8
	ps.corner_radius_bottom_left  = 8
	ps.corner_radius_bottom_right = 8
	ps.border_width_left   = 1
	ps.border_width_right  = 1
	ps.border_width_top    = 1
	ps.border_width_bottom = 1
	ps.border_color = Color(0.45, 0.28, 0.78)
	panel.add_theme_stylebox_override("panel", ps)
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = -260
	panel.offset_right  = 0
	panel.offset_top    = HUD_H + 4
	panel.offset_bottom = HUD_H + 4 + _settings_panel_height()
	panel.visible = false
	_hud.add_child(panel)

	# Scroll container so all settings remain reachable when the panel is
	# height-constrained (e.g. landscape orientation on a small phone).
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# ── Title ──
	var title := Label.new()
	title.text = "Game Menu"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
	vbox.add_child(title)

	# ── Difficulty ──
	var diff_sep := HSeparator.new()
	diff_sep.add_theme_color_override("color", Color(0.35, 0.28, 0.50))
	vbox.add_child(diff_sep)

	var diff_lbl := Label.new()
	diff_lbl.text = "Difficulty"
	diff_lbl.add_theme_font_size_override("font_size", 13)
	diff_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	vbox.add_child(diff_lbl)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", UIScale.px(8 if UIScale.is_mobile() else 4))
	vbox.add_child(diff_row)

	_menu_diff_btns.clear()
	for i in range(MainMenuScript.DIFFICULTIES.size()):
		var d: Dictionary = MainMenuScript.DIFFICULTIES[i]
		var diff_btn := _make_menu_small_button(d["label"])
		diff_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var di := i
		diff_btn.pressed.connect(func() -> void: _apply_in_game_difficulty(di))
		diff_row.add_child(diff_btn)
		_menu_diff_btns.append(diff_btn)

	# Highlight the currently active difficulty.
	_refresh_menu_diff_highlight()

	# ── Settings ──
	var settings_sep := HSeparator.new()
	settings_sep.add_theme_color_override("color", Color(0.35, 0.28, 0.50))
	vbox.add_child(settings_sep)

	var settings_lbl := Label.new()
	settings_lbl.text = "Settings"
	settings_lbl.add_theme_font_size_override("font_size", 13)
	settings_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	vbox.add_child(settings_lbl)

	vbox.add_child(_make_volume_slider())

	vbox.add_child(_make_feedback_toggle(
		"Background music",
		GameState.music_enabled,
		func(on: bool) -> void:
			GameState.music_enabled = on
			if _music_player != null:
				if on:
					_music_player.play()
				else:
					_music_player.stop()
	))
	vbox.add_child(_make_feedback_toggle(
		"Visual effects",
		GameState.feedback_visual,
		func(on: bool) -> void: GameState.feedback_visual = on
	))
	vbox.add_child(_make_feedback_toggle(
		"Snap to board",
		GameState.snap_to_board,
		func(on: bool) -> void: GameState.snap_to_board = on
	))
	vbox.add_child(_make_feedback_toggle(
		"Sound effects",
		GameState.feedback_audio,
		func(on: bool) -> void: GameState.feedback_audio = on
	))
	vbox.add_child(_make_feedback_toggle(
		"Vibration",
		GameState.feedback_haptic,
		func(on: bool) -> void: GameState.feedback_haptic = on
	))

	# ── Difficulty Options ──
	var diff_opts_sep := HSeparator.new()
	diff_opts_sep.add_theme_color_override("color", Color(0.35, 0.28, 0.50))
	vbox.add_child(diff_opts_sep)

	var diff_opts_lbl := Label.new()
	diff_opts_lbl.text = "Difficulty Options"
	diff_opts_lbl.add_theme_font_size_override("font_size", 13)
	diff_opts_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	vbox.add_child(diff_opts_lbl)

	vbox.add_child(_make_feedback_toggle(
		"Rotate pieces",
		GameState.allow_rotation,
		func(on: bool) -> void:
			GameState.allow_rotation = on
			_on_new_puzzle()
	))

	_settings_panel = panel


## Creates a labelled CheckBox row for the settings panel.
func _make_feedback_toggle(label_text: String, initial_value: bool, callback: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = initial_value
	cb.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	cb.add_theme_font_size_override("font_size", 13)
	cb.toggled.connect(callback)
	return cb


## Creates a labelled HSlider row for the master volume setting.
func _make_volume_slider() -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	container.add_child(header)

	var lbl := Label.new()
	lbl.text = "Volume"
	lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl)

	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % int(GameState.volume * 100.0)
	pct_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
	pct_lbl.add_theme_font_size_override("font_size", 13)
	header.add_child(pct_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = GameState.volume * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		GameState.volume = v / 100.0
		pct_lbl.text = "%d%%" % int(v)
		_apply_volume()
	)
	container.add_child(slider)

	return container


## Toggles the settings panel's visibility.
func _toggle_settings_panel() -> void:
	if _settings_panel != null:
		_settings_panel.visible = not _settings_panel.visible


## Applies a difficulty preset chosen inside the in-game menu.
## Updates GameState, restarts the puzzle immediately.
func _apply_in_game_difficulty(index: int) -> void:
	if index < 0 or index >= MainMenuScript.DIFFICULTIES.size():
		return
	var d: Dictionary = MainMenuScript.DIFFICULTIES[index]
	GameState.cols = d["cols"]
	GameState.rows = d["rows"]
	cols = GameState.cols
	rows = GameState.rows
	_refresh_menu_diff_highlight()
	# Close the menu and restart the puzzle with the new difficulty.
	if _settings_panel != null:
		_settings_panel.visible = false
	_on_new_puzzle()


## Highlights the difficulty button matching the current GameState cols/rows.
func _refresh_menu_diff_highlight() -> void:
	for i in range(_menu_diff_btns.size()):
		var btn := _menu_diff_btns[i]
		var d: Dictionary = MainMenuScript.DIFFICULTIES[i]
		var active: bool = (d["cols"] == GameState.cols and d["rows"] == GameState.rows)
		var sb_normal: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		var sb_hover: StyleBoxFlat  = btn.get_theme_stylebox("hover")  as StyleBoxFlat
		if sb_normal != null:
			sb_normal.bg_color = Color(0.45, 0.28, 0.78) if active else Color(0.28, 0.18, 0.52)
		if sb_hover != null:
			sb_hover.bg_color = Color(0.55, 0.38, 0.88) if active else Color(0.38, 0.25, 0.65)


## Builds the small-text button used inside the game menu (difficulty row).
func _make_menu_small_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	btn.add_theme_font_size_override("font_size", 12)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(0, UIScale.px(48 if UIScale.is_mobile() else 28))
	var margin_v: int = UIScale.px(10 if UIScale.is_mobile() else 4)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = Color(0.28, 0.18, 0.52)
			"hover":   sb.bg_color = Color(0.38, 0.25, 0.65)
			"pressed": sb.bg_color = Color(0.20, 0.12, 0.40)
		sb.corner_radius_top_left     = 5
		sb.corner_radius_top_right    = 5
		sb.corner_radius_bottom_left  = 5
		sb.corner_radius_bottom_right = 5
		sb.content_margin_left   = 6
		sb.content_margin_right  = 6
		sb.content_margin_top    = margin_v
		sb.content_margin_bottom = margin_v
		btn.add_theme_stylebox_override(state, sb)
	return btn


## Builds a fullscreen zoom overlay containing a large centred view of the
## reference image.  Hidden by default; shown when the reference panel is clicked
## and dismissed by clicking the backdrop.
func _build_zoom_overlay() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	# Render above the reference panel but below any completion card.
	_hud.add_child(overlay)

	# Semi-transparent dark backdrop — clicking anywhere on it dismisses the zoom.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	bg.gui_input.connect(_on_zoom_backdrop_input)

	# Centred card that holds the large image.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.09, 0.18, 0.96)
	ps.corner_radius_top_left     = 10
	ps.corner_radius_top_right    = 10
	ps.corner_radius_bottom_left  = 10
	ps.corner_radius_bottom_right = 10
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.55, 0.35, 0.90)
	card.add_theme_stylebox_override("panel", ps)
	# Limit card size so the image fills most of the screen without overflow.
	card.custom_minimum_size = Vector2(UIScale.px(320.0), UIScale.px(240.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var zoom_hdr := Label.new()
	zoom_hdr.text = "Reference Image (click outside to close)"
	zoom_hdr.add_theme_font_size_override("font_size", UIScale.font_size(13))
	zoom_hdr.add_theme_color_override("font_color", Color(0.65, 0.60, 0.85))
	zoom_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(zoom_hdr)

	var zoom_tex := TextureRect.new()
	zoom_tex.texture      = source_texture
	zoom_tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	zoom_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zoom_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_tex.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	zoom_tex.custom_minimum_size   = Vector2(UIScale.px(300.0), UIScale.px(220.0))
	zoom_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(zoom_tex)

	_zoom_overlay = overlay


## Handles mouse input on the reference panel thumbnail to open the zoom view.
func _on_reference_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _zoom_overlay != null:
				_zoom_overlay.visible = true


## Handles mouse input on the zoom overlay backdrop to dismiss it.
func _on_zoom_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _zoom_overlay != null:
				_zoom_overlay.visible = false


## Toggles the optional reference image panel and updates the button label.
func _toggle_preview() -> void:
	if _preview_panel == null:
		return
	_preview_panel.visible = not _preview_panel.visible
	# Also hide zoom overlay when panel is hidden.
	if _zoom_overlay != null and not _preview_panel.visible:
		_zoom_overlay.visible = false
	if _preview_toggle_btn != null:
		_preview_toggle_btn.text = "Preview: On" if _preview_panel.visible else "Preview: Off"


## Toggles workspace expand mode on mobile: hides the bottom panel to give the
## player the full screen for puzzle solving.  Pressing again restores the panel.
func _toggle_workspace_expand() -> void:
	_bottom_panel_expanded = not _bottom_panel_expanded

	if _bottom_panel != null:
		_bottom_panel.visible = _bottom_panel_expanded

	# Update toggle button label and colour to reflect the current state.
	if _bottom_panel_toggle_btn != null:
		_bottom_panel_toggle_btn.text = "▼" if _bottom_panel_expanded else "▲"
		_bottom_panel_toggle_btn.tooltip_text = "Expand workspace" if _bottom_panel_expanded else "Restore panel"
		# Highlight the button when workspace is expanded (panel hidden).
		var active_color := HUD_BTN_ACTIVE_COLOR if not _bottom_panel_expanded else HUD_BTN_NORMAL_COLOR
		_bottom_panel_toggle_btn.add_theme_color_override("font_color", active_color)


## Applies the current GameState.volume to all AudioStreamPlayers.
## Each player's volume_db is set to its base level offset by the linear-to-dB
## conversion of the master volume so that 1.0 = full and 0.0 = silent.
func _apply_volume() -> void:
	var offset: float = linear_to_db(maxf(GameState.volume, MIN_VOLUME_LINEAR))
	if _pickup_player != null:
		_pickup_player.volume_db = PICKUP_BASE_DB + offset
	if _snap_player != null:
		_snap_player.volume_db = SNAP_BASE_DB + offset
	if _complete_player != null:
		_complete_player.volume_db = COMPLETE_BASE_DB + offset
	if _music_player != null:
		_music_player.volume_db = MUSIC_BASE_DB + offset


## Builds a bottom panel containing puzzle controls, reference image, and sorting boxes.
## This panel can be toggled to maximize puzzle board space.
func _build_bottom_panel() -> void:
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.09, 0.18, 0.96)
	ps.corner_radius_top_left     = 16
	ps.corner_radius_top_right    = 16
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 3
	ps.border_color = Color(0.45, 0.28, 0.78)
	ps.shadow_size = 4
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	panel.add_theme_stylebox_override("panel", ps)

	# Anchor to bottom of screen
	panel.anchor_left   = 0.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 1.0
	panel.anchor_bottom = 1.0
	var panel_h := _get_bottom_panel_height()
	var safe_bottom := UIScale.safe_area_insets()["bottom"]
	panel.offset_top    = -(panel_h + safe_bottom)
	panel.offset_bottom = -safe_bottom
	_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_hbox)

	# Left section: Action buttons
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", UIScale.px(10 if UIScale.is_mobile() else 8))
	left_vbox.custom_minimum_size = Vector2(UIScale.px(140), 0)
	main_hbox.add_child(left_vbox)

	var actions_label := Label.new()
	actions_label.text = "Actions"
	actions_label.add_theme_font_size_override("font_size", UIScale.font_size(12))
	actions_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.85))
	left_vbox.add_child(actions_label)

	var restart_btn := _make_bottom_button("Restart")
	restart_btn.pressed.connect(_on_restart_puzzle)
	restart_btn.tooltip_text = "Restart this puzzle"
	left_vbox.add_child(restart_btn)

	var save_btn := _make_bottom_button("Save")
	save_btn.pressed.connect(_on_save_pressed)
	save_btn.tooltip_text = "Save progress"
	left_vbox.add_child(save_btn)

	_preview_toggle_btn = _make_bottom_button("Preview: On")
	_preview_toggle_btn.pressed.connect(_toggle_preview)
	_preview_toggle_btn.tooltip_text = "Show/hide reference"
	left_vbox.add_child(_preview_toggle_btn)

	# Center section: Reference image
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(center_vbox)

	var ref_label := Label.new()
	ref_label.text = "Reference Image (tap to zoom)"
	ref_label.add_theme_font_size_override("font_size", UIScale.font_size(12))
	ref_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.85))
	ref_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(ref_label)

	# Reference image with click handler
	var ref_panel := PanelContainer.new()
	var ref_ps := StyleBoxFlat.new()
	ref_ps.bg_color = Color(0.08, 0.07, 0.15, 0.8)
	ref_ps.corner_radius_top_left     = 6
	ref_ps.corner_radius_top_right    = 6
	ref_ps.corner_radius_bottom_left  = 6
	ref_ps.corner_radius_bottom_right = 6
	ref_panel.add_theme_stylebox_override("panel", ref_ps)
	ref_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ref_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	ref_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ref_panel.gui_input.connect(_on_reference_panel_input)
	center_vbox.add_child(ref_panel)

	var ref_margin := MarginContainer.new()
	ref_margin.add_theme_constant_override("margin_left",   4)
	ref_margin.add_theme_constant_override("margin_right",  4)
	ref_margin.add_theme_constant_override("margin_top",    4)
	ref_margin.add_theme_constant_override("margin_bottom", 4)
	ref_panel.add_child(ref_margin)

	var tex_rect := TextureRect.new()
	tex_rect.texture      = source_texture
	tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ref_margin.add_child(tex_rect)

	_preview_panel = ref_panel

	# Build the zoom overlay
	_build_zoom_overlay()

	# Right section: Sorting boxes
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_vbox.custom_minimum_size = Vector2(UIScale.px(140), 0)
	main_hbox.add_child(right_vbox)

	var boxes_label := Label.new()
	boxes_label.text = "Sort Boxes"
	boxes_label.add_theme_font_size_override("font_size", UIScale.font_size(12))
	boxes_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.85))
	right_vbox.add_child(boxes_label)

	# Sorting boxes scroll area
	var boxes_scroll := ScrollContainer.new()
	boxes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boxes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(boxes_scroll)

	_box_vbox = VBoxContainer.new()
	_box_vbox.add_theme_constant_override("separation", UIScale.px(8 if UIScale.is_mobile() else 4))
	_box_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boxes_scroll.add_child(_box_vbox)

	# Initialize sorting boxes
	_sorting_boxes.clear()
	for box_name: String in SORTING_BOX_DEFAULTS:
		_sorting_boxes.append({"name": box_name, "pieces": [], "button": null})

	for i in _sorting_boxes.size():
		_append_box_button(i)

	# Add custom box controls
	var add_sep := HSeparator.new()
	add_sep.add_theme_color_override("color", Color(0.35, 0.28, 0.50))
	_box_vbox.add_child(add_sep)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", UIScale.px(8 if UIScale.is_mobile() else 4))
	_box_vbox.add_child(add_row)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "New box…"
	name_edit.add_theme_font_size_override("font_size", UIScale.font_size(11))
	name_edit.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	name_edit.custom_minimum_size = Vector2(0, UIScale.px(48 if UIScale.is_mobile() else 24))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(name_edit)

	var add_btn := _make_small_icon_button("+")
	add_btn.tooltip_text = "Add custom sorting box"
	add_btn.pressed.connect(func() -> void:
		var n := name_edit.text.strip_edges()
		if n.length() > 0:
			_add_custom_box(n)
			name_edit.text = ""
	)
	add_row.add_child(add_btn)

	_bottom_panel = panel
	_build_box_view_overlay()
	_build_box_hover_popup()


## Creates a button for the bottom panel with consistent styling.
func _make_bottom_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	btn.add_theme_font_size_override("font_size", UIScale.font_size(13))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, UIScale.px(48))

	var margin_v: int = UIScale.px(10)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = Color(0.25, 0.16, 0.48)
			"hover":   sb.bg_color = Color(0.36, 0.23, 0.62)
			"pressed": sb.bg_color = Color(0.18, 0.11, 0.36)
		sb.corner_radius_top_left     = 5
		sb.corner_radius_top_right    = 5
		sb.corner_radius_bottom_left  = 5
		sb.corner_radius_bottom_right = 5
		sb.content_margin_left   = 8
		sb.content_margin_right  = 8
		sb.content_margin_top    = margin_v
		sb.content_margin_bottom = margin_v
		btn.add_theme_stylebox_override(state, sb)

	return btn


func _build_complete_overlay() -> void:
	_complete_overlay = Control.new()
	_complete_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_complete_overlay.visible = false
	_hud.add_child(_complete_overlay)

	# Dimmed backdrop – starts fully transparent; fades in when shown.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.modulate.a = 0.0
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
	# Card starts scaled down and transparent so the entrance animation can
	# spring it into view.
	card.scale = Vector2(0.80, 0.80)
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	center.add_child(card)
	_complete_card = card

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   UIScale.px(48))
	margin.add_theme_constant_override("margin_right",  UIScale.px(48))
	margin.add_theme_constant_override("margin_top",    UIScale.px(36))
	margin.add_theme_constant_override("margin_bottom", UIScale.px(36))
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var complete_title_lbl := Label.new()
	complete_title_lbl.text = "Puzzle Complete!"
	complete_title_lbl.add_theme_font_size_override("font_size", UIScale.font_size(40))
	complete_title_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	complete_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(complete_title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Well done – all pieces placed!"
	sub_lbl.add_theme_font_size_override("font_size", UIScale.font_size(18))
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.80))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	_complete_time_lbl = Label.new()
	_complete_time_lbl.text = ""
	_complete_time_lbl.add_theme_font_size_override("font_size", UIScale.font_size(22))
	_complete_time_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	_complete_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_complete_time_lbl)

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

	var lb_btn := _make_hud_button("Leaderboard")
	lb_btn.pressed.connect(_show_leaderboard_overlay)
	btn_row.add_child(lb_btn)

	# Confetti Node2D added after the card so it renders on top of everything.
	_confetti = ConfettiEffect.new()
	_hud.add_child(_confetti)

	# Glow effect lives on the board's own coordinate space so it
	# aligns with the puzzle grid.  Added to the board (not the HUD) so that
	# draw_rect coordinates match piece local positions.
	_glow_effect = PuzzleGlowEffect.new()
	add_child(_glow_effect)


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

	# Reset the workspace camera so every new puzzle starts at the default 1:1 view.
	_reset_camera()

	var viewport_size := get_viewport_rect().size

	# Fit the image into 90 % of the available area while preserving its aspect
	# ratio.  Using rectangular cells (screen_piece_w may differ from
	# screen_piece_h) ensures the assembled puzzle always shows the complete image
	# without stretching or squishing.
	var avail_w: float = viewport_size.x * 0.90
	var bottom_panel_h := _get_bottom_reserved_height() if _bottom_panel_expanded else UIScale.safe_area_insets()["bottom"]
	var avail_h: float = (viewport_size.y - HUD_H - bottom_panel_h) * 0.90

	var image := source_texture.get_image()
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var img_w := image.get_width()
	var img_h := image.get_height()

	var img_aspect: float = float(img_w) / float(img_h) if img_h > 0 else 1.0
	var avail_aspect: float = avail_w / avail_h if avail_h > 0.0 else 1.0
	var display_w: float
	var display_h: float
	if img_aspect >= avail_aspect:
		# Image is wider (relative to available area): fit to width.
		display_w = avail_w
		display_h = avail_w / img_aspect
	else:
		# Image is taller: fit to height.
		display_h = avail_h
		display_w = avail_h * img_aspect

	var screen_piece_w: float = display_w / float(cols)
	var screen_piece_h: float = display_h / float(rows)
	if screen_piece_w <= 0.0 or screen_piece_h <= 0.0:
		push_error("PuzzleBoard: screen piece dimensions must be positive (got w=%.2f h=%.2f)." % [screen_piece_w, screen_piece_h])
		return
	_piece_size = Vector2(screen_piece_w, screen_piece_h)

	# Natural piece cell size in image space.  Using the actual per-column and
	# per-row pixel counts avoids forcing the image into square cells and thereby
	# preserves the original aspect ratio of the source image.
	var image_piece_w: int = img_w / cols
	var image_piece_h: int = img_h / rows
	if image_piece_w <= 0 or image_piece_h <= 0:
		push_error("PuzzleBoard: source image too small for grid (piece size <= 0).")
		return

	# Cap source resolution so per-piece textures stay close to on-screen size,
	# reducing GPU bandwidth/memory on mobile while keeping a modest oversample.
	# Mobile uses a tighter cap (1.0×) to minimise texture memory; desktop keeps
	# the 1.35× oversample so zoomed-in views remain sharper.
	var oversample: float = 1.0 if GameState.is_mobile else SOURCE_OVERSAMPLE
	var max_source_w: int = int(ceil(screen_piece_w * oversample))
	var max_source_h: int = int(ceil(screen_piece_h * oversample))
	var pixel_scale: float = 1.0
	if image_piece_w > 0 and max_source_w > 0:
		pixel_scale = minf(pixel_scale, float(max_source_w) / float(image_piece_w))
	if image_piece_h > 0 and max_source_h > 0:
		pixel_scale = minf(pixel_scale, float(max_source_h) / float(image_piece_h))
	image_piece_w = maxi(1, int(floor(float(image_piece_w) * pixel_scale)))
	image_piece_h = maxi(1, int(floor(float(image_piece_h) * pixel_scale)))

	# Resize the image to be exactly cols × image_piece_w wide and
	# rows × image_piece_h tall so that integer-division truncation cannot
	# leave a gap at the right or bottom edge of the assembled puzzle.
	# On mobile, BILINEAR is used instead of LANCZOS to significantly reduce
	# build time; quality is indistinguishable at the small screen-space sizes
	# used by mobile puzzles.
	var target_img_w: int = cols * image_piece_w
	var target_img_h: int = rows * image_piece_h
	if image.get_width() != target_img_w or image.get_height() != target_img_h:
		var interp: int = Image.INTERPOLATE_BILINEAR if GameState.is_mobile else Image.INTERPOLATE_LANCZOS
		image.resize(target_img_w, target_img_h, interp)
		img_w = image.get_width()
		img_h = image.get_height()

	# Centre the puzzle grid on the available canvas area.
	_puzzle_origin = Vector2(
		(viewport_size.x - display_w) * 0.5,
		HUD_H + ((viewport_size.y - HUD_H - bottom_panel_h) - display_h) * 0.5
	)

	# Uniform scale factor from image-space to screen-space.
	# Because the display dimensions preserve the image aspect ratio, the same
	# factor applies to both axes: scale = display_w / img_w = display_h / img_h.
	var piece_scale: float = display_w / float(img_w) if img_w > 0 else 1.0

	var piece_data_array: Array = _generator.generate_edges(cols, rows)
	_total_pieces  = piece_data_array.size()
	_placed_pieces = 0
	_update_counter()
	_timer_elapsed = 0.0
	_timer_last_s  = -1
	_timer_running = true
	_update_timer_label()

	# Resolve the shape enum value from the string key.
	var shape_enum: int = PuzzleGeneratorScript.PieceShape.JIGSAW
	if _piece_shape == "square":
		shape_enum = PuzzleGeneratorScript.PieceShape.SQUARE

	_pieces.clear()
	_pieces_initial_positions.clear()

	# Compute spawn bounds once before the loop to avoid per-piece allocations.
	var spawn_bottom_reserved := _get_bottom_reserved_height() if _bottom_panel_expanded else UIScale.safe_area_insets()["bottom"]

	for pd in piece_data_array:
		var col: int = pd.grid_pos.x
		var row: int = pd.grid_pos.y

		# Generate polygon and masked texture in image space.
		var polygon: PackedVector2Array = _generator.generate_piece_polygon(pd, image_piece_w, image_piece_h, shape_enum)
		var region  := Rect2i(col * image_piece_w, row * image_piece_h, image_piece_w, image_piece_h)
		var texture: ImageTexture = _generator.create_piece_texture(image, region, polygon, shape_enum)

		# Correct world position: centre of the grid cell in screen space.
		var correct_pos := Vector2(
			_puzzle_origin.x + (col + 0.5) * screen_piece_w,
			_puzzle_origin.y + (row + 0.5) * screen_piece_h
		)

		var piece := PIECE_SCENE.instantiate()
		add_child(piece)

		var sprite    := piece.get_node("Sprite2D") as Sprite2D
		sprite.texture = texture
		# Scale the sprite so it displays at screen-space size.
		sprite.scale = Vector2(piece_scale, piece_scale)

		# Collision shape sized to the screen-space piece cell.
		var col_shape  := piece.get_node("CollisionShape2D") as CollisionShape2D
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(screen_piece_w, screen_piece_h)
		col_shape.shape = rect_shape

		piece.correct_position = correct_pos
		# Scale snap threshold to the shorter side of the screen-space piece so
		# snapping feels consistent regardless of grid size, resolution, or image
		# aspect ratio.  35 % is tight enough to prevent accidental snaps to
		# adjacent slots while remaining easy to hit intentionally.
		piece.snap_distance = minf(screen_piece_w, screen_piece_h) * 0.35

		# Apply a random 90° rotation when rotation difficulty is enabled.
		if GameState.allow_rotation:
			var steps: int = randi() % 4
			piece.rotation_steps = steps
			piece.rotation_degrees = steps * 90.0

		# Spawn randomly; keep pieces below the HUD bar.
		var spawn_half_w := _piece_size.x * 0.5
		var spawn_half_h := _piece_size.y * 0.5
		var spawn_pos := Vector2(
			randf_range(spawn_half_w, viewport_size.x - spawn_half_w),
			randf_range(HUD_H + spawn_half_h, viewport_size.y - spawn_bottom_reserved - spawn_half_h)
		)
		piece.position = spawn_pos
		_pieces_initial_positions.append(spawn_pos)
		piece.piece_placed.connect(on_piece_placed)
		piece.piece_picked_up.connect(on_piece_picked_up.bind(piece))
		piece.piece_released.connect(_on_piece_released)

		_pieces.append(piece)

	_animate_board_entry()


## Plays the board entry animation after each puzzle build.
##
## Two loading animations run simultaneously:
##
##   Layer A – Puzzle image fade-in
##     A full-screen dark overlay is placed on top of the freshly-built board
##     and fades to transparent over ~0.55 s, creating the impression of the
##     scattered pieces being gradually revealed from darkness.
##
##   Layer B – Puzzle pieces assembling
##     Each piece starts at scale Vector2.ZERO and springs open to its normal
##     size using an elastic ease with a 30 ms stagger between pieces.  The
##     stagger makes the board feel like it's populating piece-by-piece rather
##     than appearing all at once.
func _animate_board_entry() -> void:
	if _pieces.is_empty():
		return

	# ── Layer A: Puzzle image fade-in ──────────────────────────────────────────
	# Clean up any leftover overlay from a previous build before adding a new
	# one (can happen when "New Puzzle" is pressed during the animation).
	if is_instance_valid(_entry_overlay):
		_entry_overlay.queue_free()

	_entry_overlay = ColorRect.new()
	_entry_overlay.color = ENTRY_OVERLAY_COLOR
	_entry_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_entry_overlay)

	var overlay_tween := create_tween()
	# Smoother ease curve for the fade-in.
	overlay_tween.tween_property(_entry_overlay, "modulate:a", 0.0, 0.60) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	overlay_tween.tween_callback(func() -> void:
		if is_instance_valid(_entry_overlay):
			_entry_overlay.queue_free()
			_entry_overlay = null
	)

	# ── Layer B: Puzzle pieces assembling ──────────────────────────────────────
	# Enhanced with accelerating stagger and varied entrance easing for better flow.
	for i in _pieces.size():
		var piece = _pieces[i]
		if not is_instance_valid(piece):
			continue
		piece.scale = Vector2.ZERO
		# Accelerating delay curve - later pieces appear faster.
		var progress: float = float(i) / float(max(_pieces.size() - 1, 1))
		var delay: float = i * PIECE_STAGGER_DELAY * (1.0 - progress * 0.3)
		var piece_tween: Tween = piece.create_tween()
		piece_tween.tween_interval(delay)
		# Vary the entrance animation based on piece position for visual variety.
		if i % 3 == 0:
			# Every third piece uses TRANS_BACK for extra bounce.
			piece_tween.tween_property(piece, "scale", Vector2.ONE, 0.42) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		else:
			# Others use TRANS_CUBIC for smoother pop-in.
			piece_tween.tween_property(piece, "scale", Vector2.ONE, 0.38) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _update_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "Pieces: %d / %d" % [_placed_pieces, _total_pieces]


## Formats elapsed seconds as M:SS or H:MM:SS and refreshes the HUD timer label.
func _update_timer_label() -> void:
	if _timer_label != null:
		_timer_label.text = _format_time(_timer_elapsed)


## Converts a duration in seconds to a human-readable "M:SS" or "H:MM:SS" string.
func _format_time(seconds: float) -> String:
	var total_s: int = int(seconds)
	var h: int = total_s / 3600
	var m: int = (total_s % 3600) / 60
	var s: int = total_s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


## Called by each PuzzlePiece when it snaps into place.
func on_piece_placed() -> void:
	_placed_pieces += 1
	_update_counter()
	if GameState.feedback_audio and _snap_player != null:
		_snap_player.play()
	if _placed_pieces >= _total_pieces and _total_pieces > 0:
		_show_complete()


## Called by each PuzzlePiece when the player picks it up.
func on_piece_picked_up(piece) -> void:
	_dragged_piece = piece
	_last_drag_pos = piece.global_position
	if GameState.feedback_audio and _pickup_player != null:
		_pickup_player.play()


## Called by each PuzzlePiece when the player releases it (placed or dropped).
func _on_piece_released() -> void:
	# Capture the piece reference before clearing _dragged_piece, so we can
	# check box-drop targeting below.
	var released_piece = _dragged_piece
	_dragged_piece = null
	_last_drag_pos = Vector2.ZERO
	_clear_box_drop_highlight()
	queue_redraw()
	# If the piece was not snapped into its final slot, check whether it was
	# dropped over a sorting-box button and, if so, store it there.
	if released_piece != null and is_instance_valid(released_piece) \
			and not released_piece.is_locked:
		_try_add_piece_to_box(released_piece)


## Displays the completion overlay with an entrance animation, plays the
## completion fanfare, and launches the confetti victory effect.
##
## Victory animation sequence:
##   1. Backdrop fades in (0.25 s, alpha 0 → 0.65)
##   2. Card scales up from 0.8× to 1.0× with an elastic overshoot (0.35 s,
##      ease-out back) and simultaneously fades in from transparent to opaque.
##   3. Confetti rain begins (3.5 s spawn window).
##   4. Puzzle glow + piece celebration wave play on the board behind the card.
func _show_complete() -> void:
	_timer_running = false
	_update_timer_label()
	# Clear the save slot so "Resume" is not shown in the menu after completion.
	_clear_save()
	# Persist this run's score to the leaderboard.
	GameState.save_score(_timer_elapsed, cols, rows)
	if _complete_time_lbl != null:
		_complete_time_lbl.text = "Time: %s" % _format_time(_timer_elapsed)
	# Dismiss the zoom overlay so it does not cover the completion card.
	if _zoom_overlay != null:
		_zoom_overlay.visible = false
	if _complete_overlay != null:
		_complete_overlay.visible = true

		# Animate backdrop and card entrance when visual feedback is on.
		if GameState.feedback_visual:
			# Find the dim backdrop (first child of _complete_overlay).
			var dim := _complete_overlay.get_child(0) as ColorRect
			if dim != null:
				var dim_tween := create_tween()
				# Slower, smoother fade-in for the backdrop.
				dim_tween.tween_property(dim, "modulate:a", 1.0, 0.32) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

			# Scale + fade the card with a short delay so the backdrop appears first.
			if _complete_card != null:
				var card_tween := create_tween()
				card_tween.tween_interval(0.12)
				# Add anticipation: start slightly smaller then bounce to full size.
				card_tween.tween_property(_complete_card, "scale", Vector2(0.75, 0.75), 0.0)
				card_tween.tween_property(_complete_card, "scale", Vector2(1.08, 1.08), 0.28) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				# Final settle with elastic overshoot.
				card_tween.tween_property(_complete_card, "scale", Vector2.ONE, 0.18) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
				# Fade in parallel to the initial bounce.
				card_tween.parallel().tween_property(_complete_card, "modulate:a", 1.0, 0.28) \
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		else:
			# Instant show when visual feedback is disabled.
			var dim := _complete_overlay.get_child(0) as ColorRect
			if dim != null:
				dim.modulate.a = 1.0
			if _complete_card != null:
				_complete_card.scale = Vector2.ONE
				_complete_card.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if GameState.feedback_audio and _complete_player != null:
		_complete_player.play()
	if GameState.feedback_visual and _confetti != null:
		_confetti.start(get_viewport().get_visible_rect().size)
	if GameState.feedback_visual and _glow_effect != null and _piece_size != Vector2.ZERO:
		var puzzle_rect := Rect2(_puzzle_origin, Vector2(cols * _piece_size.x, rows * _piece_size.y))
		_glow_effect.start(puzzle_rect)
		_play_piece_celebration_wave()


## Piece Celebration Wave
## Triggers a brief cascade of scale-bounce + gold-flash animations through all
## locked pieces, staggered by their grid distance from the top-left corner.
## Enhanced with varied timing and stronger visual impact.
func _play_piece_celebration_wave() -> void:
	if _piece_size == Vector2.ZERO:
		return
	for child: Node in get_tree().get_nodes_in_group("puzzle_pieces"):
		# All nodes in "puzzle_pieces" are PuzzlePiece Area2D instances; guard
		# against unlocked pieces (not yet placed) using duck-typed property access.
		if not child.get("is_locked"):
			continue
		var sprite := child.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			continue
		var correct_pos = child.get("correct_position")
		if correct_pos == null:
			continue
		var col: int = int((correct_pos.x - _puzzle_origin.x) / _piece_size.x)
		var row: int = int((correct_pos.y - _puzzle_origin.y) / _piece_size.y)
		# Varied stagger based on position creates a more dynamic wave.
		var delay: float = float(col + row) * 0.048 + randf_range(0.0, 0.015)
		var tween := create_tween()
		tween.tween_interval(delay)
		# Stronger pop with brighter gold flash.
		tween.tween_property(sprite, "scale", Vector2(1.22, 1.22), 0.10) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(sprite, "modulate", Color(1.7, 1.5, 0.1, 1.0), 0.10)
		# Longer elastic bounce back for more satisfying settle.
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)


# ─── Leaderboard overlay ──────────────────────────────────────────────────────

## Builds (or rebuilds) and shows the full-screen leaderboard overlay.
## Displays scores for every known difficulty, with the current puzzle's
## difficulty section scrolled into view first.
func _show_leaderboard_overlay() -> void:
	# Remove any previous overlay before rebuilding so content is always fresh.
	if _leaderboard_overlay != null and is_instance_valid(_leaderboard_overlay):
		_leaderboard_overlay.queue_free()
	_leaderboard_overlay = null

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(overlay)
	_leaderboard_overlay = overlay

	# Dimmed backdrop.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	# Centred card.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.10, 0.22, 0.98)
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
	card.custom_minimum_size = Vector2(UIScale.px(400), UIScale.px(320))
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

	# Title row with close button.
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Leaderboard"
	title_lbl.add_theme_font_size_override("font_size", UIScale.font_size(28))
	title_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := _make_hud_button("✕ Close")
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

	# Build a section for each known difficulty.
	var diffs: Array[Dictionary] = MainMenuScript.DIFFICULTIES
	var any_scores := false
	for d: Dictionary in diffs:
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
				Color(1.0, 0.85, 0.25) if rank == 0 else Color(0.65, 0.60, 0.80))
			row_hbox.add_child(rank_lbl)

			var time_lbl := Label.new()
			time_lbl.text = GameState.format_score_time(e.get("time", 0.0))
			time_lbl.add_theme_font_size_override("font_size", UIScale.font_size(14))
			time_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
			time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_hbox.add_child(time_lbl)

			var date_lbl := Label.new()
			date_lbl.text = e.get("date", "")
			date_lbl.add_theme_font_size_override("font_size", UIScale.font_size(13))
			date_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.65))
			row_hbox.add_child(date_lbl)

	if not any_scores:
		var empty_lbl := Label.new()
		empty_lbl.text = "No scores yet – complete a puzzle to get on the board!"
		empty_lbl.add_theme_font_size_override("font_size", UIScale.font_size(15))
		empty_lbl.add_theme_color_override("font_color", Color(0.58, 0.55, 0.68))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scores_vbox.add_child(empty_lbl)


## Creates and returns an AudioStreamPlayer loaded with a generated pickup sound.
func _create_pickup_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = PICKUP_BASE_DB
	player.stream = _generate_pickup_sound()
	return player


## Generates a short ascending-chirp "pickup" sound as a raw AudioStreamWAV.
## The chirp rises from 440 Hz to 880 Hz, making it clearly distinct from the
## descending snap sound, and decays quickly for a light, airy feel.
func _generate_pickup_sound() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 0.08
	var num_samples: int = int(sample_rate * duration)

	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono = 2 bytes per sample.

	for i in range(num_samples):
		var t: float        = float(i) / float(sample_rate)
		var progress: float = float(i) / float(num_samples)
		# Ascending chirp from 440 Hz to 880 Hz with a gentle exponential decay.
		var freq: float     = lerp(440.0, 880.0, progress)
		var envelope: float = exp(-progress * 20.0)
		var sample: int     = int(sin(TAU * freq * t) * envelope * 18000.0)
		sample = clampi(sample, -32768, 32767)
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo   = false
	stream.data     = data
	return stream


## Creates and returns an AudioStreamPlayer loaded with a generated snap sound.
func _create_snap_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = SNAP_BASE_DB
	player.stream = _generate_snap_sound()
	return player


## Creates and returns an AudioStreamPlayer loaded with looping background music.
func _create_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = MUSIC_BASE_DB
	player.stream = _generate_music_stream()
	return player


## Generates a gentle ambient looping background music track as a raw AudioStreamWAV.
## The track blends three harmonically-related sine waves (a soft major chord) with
## a slow tremolo so the loop boundary is smooth.
func _generate_music_stream() -> AudioStreamWAV:
	var sample_rate: int  = 22050
	var duration: float   = 6.0  # seconds – long enough not to feel repetitive.
	var num_samples: int  = int(sample_rate * duration)

	# Frequencies for a calm C-major chord one octave above middle C.
	var freq_root:  float = 261.63  # C4
	var freq_third: float = 329.63  # E4
	var freq_fifth: float = 392.00  # G4
	# A gentle sub-octave to add warmth.
	var freq_sub:   float = 130.81  # C3

	# Slow tremolo cycle (matches the loop length so start == end amplitude).
	var tremolo_rate: float = 1.0 / duration

	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono = 2 bytes per sample.

	# Pre-compute loop-invariant fade region length (0.1 s).
	var fade_samples: int = int(sample_rate * 0.1)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)

		# Fade the very first and last 0.1 s to avoid a click at the loop point.
		# fade-out uses (num_samples - 1 - i) so the very last sample is exactly 0,
		# matching the fade-in start value and eliminating the loop-boundary click.
		var fade: float = 1.0
		if i < fade_samples:
			fade = float(i) / float(fade_samples)
		elif i >= num_samples - fade_samples:
			fade = float(num_samples - 1 - i) / float(fade_samples)

		# Smooth tremolo oscillating between 0.5 and 1.0.
		var tremolo: float = 0.75 + 0.25 * sin(TAU * tremolo_rate * t)

		var wave: float = (
			sin(TAU * freq_root  * t) * 0.40 +
			sin(TAU * freq_third * t) * 0.30 +
			sin(TAU * freq_fifth * t) * 0.20 +
			sin(TAU * freq_sub   * t) * 0.10
		)

		var amplitude: int = int(wave * tremolo * fade * 10000.0)
		amplitude = clampi(amplitude, -32768, 32767)
		data[i * 2]     = amplitude & 0xFF
		data[i * 2 + 1] = (amplitude >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format     = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate   = sample_rate
	stream.stereo     = false
	stream.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end   = num_samples
	stream.data       = data
	return stream


## Generates a short descending-chirp "snap" sound as a raw AudioStreamWAV.
func _generate_snap_sound() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 0.12
	var num_samples: int = int(sample_rate * duration)

	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono = 2 bytes per sample.

	for i in range(num_samples):
		var t: float        = float(i) / float(sample_rate)
		var progress: float = float(i) / float(num_samples)
		# Descending chirp from 880 Hz to 440 Hz with a fast exponential decay.
		var freq: float     = lerp(880.0, 440.0, progress)
		var envelope: float = exp(-progress * 28.0)
		var sample: int     = int(sin(TAU * freq * t) * envelope * 28000.0)
		sample = clampi(sample, -32768, 32767)
		# Store as little-endian signed 16-bit.
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format    = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate  = sample_rate
	stream.stereo    = false
	stream.data      = data
	return stream


## Creates and returns an AudioStreamPlayer loaded with a generated completion fanfare.
func _create_complete_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = COMPLETE_BASE_DB
	player.stream = _generate_completion_sound()
	return player


## Generates a celebratory ascending-arpeggio fanfare as a raw AudioStreamWAV.
## Four notes of a C-major chord (C5→E5→G5→C6) are played in sequence, each
## with a soft decay, giving a sound clearly distinct from the short snap chirp.
func _generate_completion_sound() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float  = 1.0
	var num_samples: int = int(sample_rate * duration)

	# Ascending C-major arpeggio: C5, E5, G5, C6.
	var notes: Array[float] = [
		523.25,  # C5
		659.25,  # E5
		783.99,  # G5
		1046.50, # C6
	]
	var note_duration: float = duration / float(notes.size())

	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono = 2 bytes per sample.

	for i in range(num_samples):
		var t: float        = float(i) / float(sample_rate)
		var note_index: int = clampi(int(t / note_duration), 0, notes.size() - 1)
		var note_t: float   = t - note_index * note_duration
		var freq: float     = notes[note_index]
		# Gentle per-note decay so each note is crisp at its onset.
		var envelope: float = exp(-note_t * 6.0)
		var sample: int     = int(sin(TAU * freq * t) * envelope * 28000.0)
		sample = clampi(sample, -32768, 32767)
		# Store as little-endian signed 16-bit.
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo   = false
	stream.data     = data
	return stream


## Returns to the main menu.
func _on_back_pressed() -> void:
	_timer_running = false
	if _music_player != null:
		_music_player.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ─── Save / Load ──────────────────────────────────────────────────────────────

## Saves the current puzzle state (piece positions + lock states + timer) to
## the single save slot at SAVE_PATH.  Updates GameState.has_save and refreshes
## the HUD indicator.
func _on_save_pressed() -> void:
	_save_puzzle_state()


## Writes the current puzzle state to SAVE_PATH as JSON.
func _save_puzzle_state() -> void:
	if _pieces.is_empty():
		return

	var pieces_data: Array = []
	for piece in _pieces:
		if not is_instance_valid(piece):
			push_warning("PuzzleBoard: cannot save – a piece node is no longer valid.")
			return
		pieces_data.append({
			"pos_x": piece.position.x,
			"pos_y": piece.position.y,
			"is_locked": piece.is_locked,
			"rotation_steps": piece.rotation_steps
		})

	var save_data: Dictionary = {
		"version": 1,
		"image_path": GameState.image_path,
		"gallery_index": GameState.gallery_index,
		"cols": cols,
		"rows": rows,
		"piece_shape": _piece_shape,
		"allow_rotation": GameState.allow_rotation,
		"elapsed_time": _timer_elapsed,
		"pieces": pieces_data
	}

	var json_string := JSON.stringify(save_data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("PuzzleBoard: Failed to open save file for writing (error %d)." % FileAccess.get_open_error())
		return
	file.store_string(json_string)
	file.close()

	GameState.has_save = true
	_update_save_slot_label(true)
	_show_save_notification()


## Reads the saved state from SAVE_PATH and applies it to the already-built
## puzzle (piece positions, lock states, and elapsed timer).
## Called after _build_puzzle() when GameState.resume_save was true.
func _apply_saved_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("PuzzleBoard: No save file found at %s" % SAVE_PATH)
		return
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning("PuzzleBoard: Failed to parse save file JSON.")
		return

	var save_data: Dictionary = json.get_data()
	if not save_data.has("pieces"):
		push_warning("PuzzleBoard: Save file missing 'pieces' key.")
		return

	var pieces_data: Array = save_data["pieces"]
	if pieces_data.size() != _pieces.size():
		push_warning("PuzzleBoard: Save piece count (%d) differs from current (%d); skipping restore." \
			% [pieces_data.size(), _pieces.size()])
		return

	# Restore the elapsed time; _timer_running is already true from _build_puzzle().
	_timer_elapsed = float(save_data.get("elapsed_time", 0.0))
	_timer_last_s  = -1
	_update_timer_label()

	# Restore each piece's position, locked state, and rotation.
	_placed_pieces = 0
	for i in range(_pieces.size()):
		var piece = _pieces[i]
		if not is_instance_valid(piece):
			continue
		var pd: Dictionary = pieces_data[i]
		piece.position = Vector2(float(pd.get("pos_x", 0.0)), float(pd.get("pos_y", 0.0)))
		var steps: int = int(pd.get("rotation_steps", 0))
		piece.rotation_steps = steps
		piece.rotation_degrees = steps * 90.0
		var locked: bool = bool(pd.get("is_locked", false))
		if locked:
			piece.is_locked       = true
			piece.input_pickable  = false
			_placed_pieces       += 1

	_update_counter()
	_update_save_slot_label(true)


## Deletes the save file and clears the has_save flag.
## Called on puzzle completion, restart, and new-puzzle to keep the save
## slot consistent with the current game state.
func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	GameState.has_save = false
	_update_save_slot_label(false)


## Updates the save-slot indicator label in the HUD.
## *saved* = true shows "Saved", false hides the label.
func _update_save_slot_label(saved: bool) -> void:
	if _save_slot_label == null:
		return
	_save_slot_label.text = "Saved"
	_save_slot_label.visible = saved


## Shows a brief "Game saved!" toast label that fades out after 1.5 s.
func _show_save_notification() -> void:
	var lbl := Label.new()
	lbl.text = "Game saved!"
	lbl.add_theme_font_size_override("font_size", UIScale.font_size(15))
	lbl.add_theme_color_override("font_color", Color(0.60, 0.95, 0.70))
	# Anchor the toast to the top centre of the HUD.
	lbl.anchor_left   = 0.5
	lbl.anchor_right  = 0.5
	lbl.anchor_top    = 0.0
	lbl.anchor_bottom = 0.0
	lbl.offset_left   = -80
	lbl.offset_right  = 80
	lbl.offset_top    = HUD_H + 6
	lbl.offset_bottom = HUD_H + 30
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(lbl)

	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(lbl.queue_free)


## Resets all pieces to their initial positions without rebuilding the puzzle.
## Pieces are returned to their starting locations and their locked state is
## cleared so the puzzle can be solved again from the beginning.
func _on_restart_puzzle() -> void:
	if _building:
		return

	_reset_camera()

	if _complete_overlay != null:
		_complete_overlay.visible = false

	if _confetti != null:
		_confetti.stop()

	if _complete_player != null:
		_complete_player.stop()

	# Dismiss any in-progress entry overlay immediately.
	if is_instance_valid(_entry_overlay):
		_entry_overlay.queue_free()
		_entry_overlay = null

	# Return all pieces from sorting boxes so the restart loop can reposition them.
	_clear_all_sorting_boxes()

	# Discard any saved state: after a restart the pieces are at new positions.
	_clear_save()

	_placed_pieces = 0
	_update_counter()
	_timer_elapsed = 0.0
	_timer_last_s  = -1
	_timer_running = true
	_update_timer_label()

	for i in range(_pieces.size()):
		var piece = _pieces[i]
		if not is_instance_valid(piece):
			continue
		piece.is_locked = false
		piece.input_pickable = true
		piece.visible = true
		piece.z_index = 0
		# Re-apply a fresh random rotation when rotation difficulty is enabled.
		if GameState.allow_rotation:
			var steps: int = randi() % 4
			piece.rotation_steps = steps
			piece.rotation_degrees = steps * 90.0
		else:
			piece.rotation_steps = 0
			piece.rotation_degrees = 0.0
		if i < _pieces_initial_positions.size():
			piece.position = _pieces_initial_positions[i]
		else:
			push_warning("PuzzleBoard: _pieces_initial_positions out of sync at index %d" % i)


## Clears all pieces and rebuilds the puzzle with the same image.
func _on_new_puzzle() -> void:
	if _building:
		return
	_building = true

	if _complete_overlay != null:
		_complete_overlay.visible = false

	if _confetti != null:
		_confetti.stop()

	if _complete_player != null:
		_complete_player.stop()

	# Dismiss any in-progress entry overlay immediately.
	if is_instance_valid(_entry_overlay):
		_entry_overlay.queue_free()
		_entry_overlay = null

	# Clear box piece lists before freeing pieces so references don't linger.
	_clear_all_sorting_boxes()

	# Discard any saved state: new puzzle means a fresh start.
	_clear_save()

	for piece in get_tree().get_nodes_in_group("puzzle_pieces"):
		piece.queue_free()
	_pieces.clear()
	_pieces_initial_positions.clear()

	_placed_pieces = 0
	_total_pieces  = 0
	_update_counter()
	_timer_elapsed = 0.0
	_timer_last_s  = -1
	_timer_running = false
	_update_timer_label()

	# Wait one frame so queue_free calls have resolved before rebuilding.
	await get_tree().process_frame
	_build_puzzle()
	_building = false


# ─── Sorting boxes ────────────────────────────────────────────────────────────

## Appends a styled button for the sorting box at box_idx to _box_vbox,
## inserting it before the separator so box buttons always stay above it.
func _append_box_button(box_idx: int) -> void:
	if _box_vbox == null or box_idx < 0 or box_idx >= _sorting_boxes.size():
		return
	var box: Dictionary = _sorting_boxes[box_idx]

	var btn := Button.new()
	var box_pieces: Array = box.pieces
	btn.text = "%s [%d]" % [box.name, box_pieces.size()]
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, UIScale.px(48 if UIScale.is_mobile() else 28))
	btn.tooltip_text = "Open box: %s\n(drop pieces here to sort them)" % box.name
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var margin_v: int = UIScale.px(10 if UIScale.is_mobile() else 3)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = Color(0.25, 0.16, 0.48)
			"hover":   sb.bg_color = Color(0.36, 0.23, 0.62)
			"pressed": sb.bg_color = Color(0.18, 0.11, 0.36)
		sb.corner_radius_top_left     = 5
		sb.corner_radius_top_right    = 5
		sb.corner_radius_bottom_left  = 5
		sb.corner_radius_bottom_right = 5
		sb.content_margin_left   = 6
		sb.content_margin_right  = 6
		sb.content_margin_top    = margin_v
		sb.content_margin_bottom = margin_v
		btn.add_theme_stylebox_override(state, sb)

	var i := box_idx
	btn.pressed.connect(func() -> void: _open_box_view(i))
	btn.mouse_entered.connect(func() -> void: _show_box_hover_preview(i, btn))
	btn.mouse_exited.connect(_hide_box_hover_preview)
	box.button = btn
	_box_vbox.add_child(btn)
	# Keep the button before the separator: index 0 is the header label,
	# so box buttons occupy indices 1 … N.
	_box_vbox.move_child(btn, 1 + box_idx)


## Creates a small square icon button used in the sorting-box panel.
func _make_small_icon_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	var btn_size: int = UIScale.px(48 if UIScale.is_mobile() else 32)
	btn.custom_minimum_size = Vector2(btn_size, btn_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":  sb.bg_color = Color(0.28, 0.18, 0.52)
			"hover":   sb.bg_color = Color(0.38, 0.25, 0.65)
			"pressed": sb.bg_color = Color(0.20, 0.12, 0.40)
		sb.corner_radius_top_left     = 4
		sb.corner_radius_top_right    = 4
		sb.corner_radius_bottom_left  = 4
		sb.corner_radius_bottom_right = 4
		sb.content_margin_left   = 2
		sb.content_margin_right  = 2
		sb.content_margin_top    = 2
		sb.content_margin_bottom = 2
		btn.add_theme_stylebox_override(state, sb)
	return btn


## Builds the full-screen box-view overlay (hidden until a box is opened).
## Piece thumbnails fill a scrollable grid; clicking one returns it to the table.
func _build_box_view_overlay() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	_hud.add_child(overlay)

	# Dark semi-transparent backdrop — clicking anywhere on it closes the view.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)
	bg.gui_input.connect(_on_box_view_backdrop_input)

	# Centred card.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.10, 0.09, 0.18, 0.96)
	ps.corner_radius_top_left     = 10
	ps.corner_radius_top_right    = 10
	ps.corner_radius_bottom_left  = 10
	ps.corner_radius_bottom_right = 10
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color = Color(0.55, 0.35, 0.90)
	card.add_theme_stylebox_override("panel", ps)
	card.custom_minimum_size = Vector2(UIScale.px(320.0), UIScale.px(200.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left",   12)
	inner_margin.add_theme_constant_override("margin_right",  12)
	inner_margin.add_theme_constant_override("margin_top",    10)
	inner_margin.add_theme_constant_override("margin_bottom", 10)
	inner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_margin.add_child(vbox)

	# Title row: box name left, close button right.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = ""
	title_lbl.add_theme_font_size_override("font_size", UIScale.font_size(14))
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title_lbl)
	_box_view_title = title_lbl

	var close_btn := _make_small_icon_button("X")
	close_btn.tooltip_text = "Close box view"
	close_btn.pressed.connect(_close_box_view)
	title_row.add_child(close_btn)

	# Hint label.
	var hint := Label.new()
	hint.text = "Click a piece to return it to the table"
	hint.add_theme_font_size_override("font_size", UIScale.font_size(11))
	hint.add_theme_color_override("font_color", Color(0.60, 0.55, 0.80))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)

	# Scrollable grid of piece thumbnails.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(UIScale.px(296.0), UIScale.px(140.0))
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(grid)
	_box_view_grid = grid

	_box_view_overlay = overlay


## Builds the lightweight hover-preview popup used to display piece thumbnails
## when the player hovers over a sorting-box button.  Hidden by default.
func _build_box_hover_popup() -> void:
	var popup := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.10, 0.09, 0.18, 0.95)
	ps.corner_radius_top_left     = 6
	ps.corner_radius_top_right    = 6
	ps.corner_radius_bottom_left  = 6
	ps.corner_radius_bottom_right = 6
	ps.border_width_left   = 1
	ps.border_width_right  = 1
	ps.border_width_top    = 1
	ps.border_width_bottom = 1
	ps.border_color = Color(0.55, 0.35, 0.90)
	popup.add_theme_stylebox_override("panel", ps)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor to top-left so size is content-driven and position sets the corner.
	popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	popup.visible = false
	_hud.add_child(popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = ""
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)
	popup.set_meta("title_lbl", title_lbl)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(grid)
	_box_hover_popup_grid = grid

	_box_hover_popup = popup


## Shows a small floating preview of piece thumbnails when hovering a box button.
func _show_box_hover_preview(box_idx: int, btn: Button) -> void:
	if _box_hover_popup == null \
			or box_idx < 0 \
			or box_idx >= _sorting_boxes.size():
		return

	var box: Dictionary = _sorting_boxes[box_idx]
	var box_pieces: Array = box.pieces

	# Update title label.
	var title_lbl := _box_hover_popup.get_meta("title_lbl") as Label
	if title_lbl != null:
		title_lbl.text = "%s  (%d piece%s)" % [
			box.name,
			box_pieces.size(),
			"" if box_pieces.size() == 1 else "s",
		]

	# Rebuild thumbnail grid.  Remove children from the tree first so stale
	# thumbnails are not rendered alongside the incoming replacements.
	for child in _box_hover_popup_grid.get_children():
		_box_hover_popup_grid.remove_child(child)
		child.queue_free()

	if box_pieces.is_empty():
		_box_hover_popup_grid.columns = 1
		var empty_lbl := Label.new()
		empty_lbl.text = "Empty"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.75))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box_hover_popup_grid.add_child(empty_lbl)
	else:
		var max_shown: int = mini(9, box_pieces.size())
		_box_hover_popup_grid.columns = mini(3, max_shown)
		for pi in max_shown:
			var piece = box_pieces[pi]
			if not is_instance_valid(piece):
				continue
			var sprite := piece.get_node_or_null("Sprite2D") as Sprite2D
			var thumb := TextureRect.new()
			thumb.custom_minimum_size = Vector2(48, 48)
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if sprite != null and sprite.texture != null:
				thumb.texture      = sprite.texture
				thumb.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
				thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_box_hover_popup_grid.add_child(thumb)

	# Position the popup to the right of the box panel, aligned with the button.
	var btn_rect := btn.get_global_rect()
	_box_hover_popup.position = Vector2(
		REFERENCE_PANEL_MARGIN + BOX_PANEL_W + 6.0,
		btn_rect.position.y
	)
	_box_hover_popup.visible = true


## Hides the sorting-box hover-preview popup.
func _hide_box_hover_preview() -> void:
	if _box_hover_popup != null:
		_box_hover_popup.visible = false


## Opens the box-view overlay for the sorting box at box_idx.
func _open_box_view(box_idx: int) -> void:
	if box_idx < 0 or box_idx >= _sorting_boxes.size():
		return
	_hide_box_hover_preview()
	_open_box_index = box_idx
	_refresh_box_view()
	if _box_view_overlay != null:
		_box_view_overlay.visible = true


## Closes the box-view overlay.
func _close_box_view() -> void:
	_open_box_index = -1
	if _box_view_overlay != null:
		_box_view_overlay.visible = false


## Dismisses the box-view overlay when the player clicks the dark backdrop.
func _on_box_view_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_box_view()


## Rebuilds the thumbnail grid to reflect the current contents of the open box.
func _refresh_box_view() -> void:
	if _box_view_grid == null \
			or _open_box_index < 0 \
			or _open_box_index >= _sorting_boxes.size():
		return

	var box: Dictionary = _sorting_boxes[_open_box_index]
	var box_pieces: Array = box.pieces

	if _box_view_title != null:
		_box_view_title.text = "Box: %s  (%d piece%s)" % [
			box.name,
			box_pieces.size(),
			"" if box_pieces.size() == 1 else "s",
		]

	# Clear existing thumbnails.  Remove from tree immediately so they are not
	# rendered alongside the incoming replacements before queue_free fires.
	for child in _box_view_grid.get_children():
		_box_view_grid.remove_child(child)
		child.queue_free()

	if box_pieces.is_empty():
		_box_view_grid.columns = 1
		var empty_lbl := Label.new()
		empty_lbl.text = "No pieces stored here.\nDrag pieces onto this box to sort them."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.75))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box_view_grid.add_child(empty_lbl)
		return

	_box_view_grid.columns = 4
	for pi in box_pieces.size():
		var piece = box_pieces[pi]
		if not is_instance_valid(piece):
			continue

		var thumb_btn := Button.new()
		thumb_btn.custom_minimum_size = Vector2(64, 64)
		thumb_btn.tooltip_text = "Return to table"
		thumb_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			match state:
				"normal":  sb.bg_color = Color(0.20, 0.16, 0.38)
				"hover":   sb.bg_color = Color(0.32, 0.25, 0.55)
				"pressed": sb.bg_color = Color(0.14, 0.10, 0.28)
			sb.corner_radius_top_left     = 6
			sb.corner_radius_top_right    = 6
			sb.corner_radius_bottom_left  = 6
			sb.corner_radius_bottom_right = 6
			sb.content_margin_left   = 2
			sb.content_margin_right  = 2
			sb.content_margin_top    = 2
			sb.content_margin_bottom = 2
			thumb_btn.add_theme_stylebox_override(state, sb)

		var sprite := piece.get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null and sprite.texture != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture      = sprite.texture
			tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Button is not a Container, so size_flags are ignored.  Use anchors
			# instead so the TextureRect always fills the entire button area.
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumb_btn.add_child(tex_rect)

		var current_pi := pi
		var current_box_idx := _open_box_index
		thumb_btn.pressed.connect(func() -> void:
			_remove_piece_from_box(current_box_idx, current_pi)
		)
		_box_view_grid.add_child(thumb_btn)


## Adds the given piece to the sorting box at box_idx, hiding it from the table.
func _add_piece_to_box(box_idx: int, piece) -> void:
	if box_idx < 0 or box_idx >= _sorting_boxes.size():
		return
	if not is_instance_valid(piece):
		return
	var box: Dictionary = _sorting_boxes[box_idx]
	var box_pieces: Array = box.pieces
	box_pieces.append(piece)
	piece.visible = false
	var btn: Button = box.get("button")
	if btn != null and is_instance_valid(btn):
		btn.text = "%s [%d]" % [box.name, box_pieces.size()]

	# Refresh the overlay so the new thumbnail appears immediately.
	if _open_box_index == box_idx:
		_refresh_box_view()


## Removes the piece at piece_idx from the box and returns it to the table.
## The piece is placed at a random position within the visible viewport area.
func _remove_piece_from_box(box_idx: int, piece_idx: int) -> void:
	if box_idx < 0 or box_idx >= _sorting_boxes.size():
		return
	var box: Dictionary = _sorting_boxes[box_idx]
	var box_pieces: Array = box.pieces
	if piece_idx < 0 or piece_idx >= box_pieces.size():
		return

	var piece = box_pieces[piece_idx]
	box_pieces.remove_at(piece_idx)

	if is_instance_valid(piece):
		piece.visible = true
		var vp := get_viewport_rect().size
		var half_w: float = _piece_size.x * 0.5 if _piece_size != Vector2.ZERO else 40.0
		var half_h: float = _piece_size.y * 0.5 if _piece_size != Vector2.ZERO else 40.0
		piece.position = Vector2(
			randf_range(half_w, vp.x - half_w),
			randf_range(HUD_H + half_h, vp.y - half_h)
		)

	var btn: Button = box.get("button")
	if btn != null and is_instance_valid(btn):
		btn.text = "%s [%d]" % [box.name, box_pieces.size()]

	# Refresh the overlay so the removed thumbnail disappears immediately.
	if _open_box_index == box_idx:
		_refresh_box_view()


## Checks whether the recently-released piece was dropped over a sorting-box
## button and, if so, stores it inside that box.
func _try_add_piece_to_box(piece) -> void:
	if not is_instance_valid(piece):
		return
	var mouse_pos := get_viewport().get_mouse_position()
	for i in _sorting_boxes.size():
		var btn: Button = _sorting_boxes[i].get("button")
		if btn == null or not is_instance_valid(btn):
			continue
		if btn.get_global_rect().has_point(mouse_pos):
			_add_piece_to_box(i, piece)
			return


## Updates the drop-target highlight on sorting-box buttons while a piece is
## being dragged.  Highlights the button under the mouse cursor and clears the
## highlight when the cursor moves away.
func _update_box_drop_highlight() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var hovered_idx: int = -1
	for i in _sorting_boxes.size():
		var btn: Button = _sorting_boxes[i].get("button")
		if btn != null and is_instance_valid(btn) and btn.get_global_rect().has_point(mouse_pos):
			hovered_idx = i
			break
	if hovered_idx != _drag_highlight_box_idx:
		_clear_box_drop_highlight()
		if hovered_idx != -1:
			_set_box_drop_highlight(hovered_idx)


## Applies a drop-target highlight style to the sorting-box button at box_idx.
func _set_box_drop_highlight(box_idx: int) -> void:
	if box_idx < 0 or box_idx >= _sorting_boxes.size():
		return
	var btn: Button = _sorting_boxes[box_idx].get("button")
	if btn == null or not is_instance_valid(btn):
		return
	_drag_highlight_box_idx = box_idx
	var sb := _make_box_button_style(Color(0.42, 0.72, 0.42), true)
	btn.add_theme_stylebox_override("normal", sb)


## Removes the drop-target highlight from the currently highlighted box button,
## restoring it to its default style.
func _clear_box_drop_highlight() -> void:
	if _drag_highlight_box_idx == -1:
		return
	var box_idx := _drag_highlight_box_idx
	_drag_highlight_box_idx = -1
	if box_idx < 0 or box_idx >= _sorting_boxes.size():
		return
	var btn: Button = _sorting_boxes[box_idx].get("button")
	if btn == null or not is_instance_valid(btn):
		return
	var sb := _make_box_button_style(Color(0.25, 0.16, 0.48), false)
	btn.add_theme_stylebox_override("normal", sb)


## Creates a StyleBoxFlat for a sorting-box button with the given background
## color.  When highlighted is true a contrasting green border is added to
## signal that the box is a valid drop target.
func _make_box_button_style(bg_color: Color, highlighted: bool) -> StyleBoxFlat:
	var margin_v: int = UIScale.px(10 if UIScale.is_mobile() else 3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	if highlighted:
		sb.border_color = Color(0.55, 0.90, 0.55)
		sb.border_width_left   = 2
		sb.border_width_right  = 2
		sb.border_width_top    = 2
		sb.border_width_bottom = 2
	sb.corner_radius_top_left     = 5
	sb.corner_radius_top_right    = 5
	sb.corner_radius_bottom_left  = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left   = 6
	sb.content_margin_right  = 6
	sb.content_margin_top    = margin_v
	sb.content_margin_bottom = margin_v
	return sb


## Adds a new custom sorting box and appends its button to the panel.
func _add_custom_box(box_name: String) -> void:
	var new_idx := _sorting_boxes.size()
	_sorting_boxes.append({"name": box_name, "pieces": [], "button": null})
	_append_box_button(new_idx)


## Returns all pieces from every sorting box to the table and clears box data.
## Does not reset piece positions – callers handle that separately if needed.
func _clear_all_sorting_boxes() -> void:
	for box in _sorting_boxes:
		var box_pieces: Array = box.pieces
		for piece in box_pieces:
			if is_instance_valid(piece):
				piece.visible = true
		box_pieces.clear()
		var btn: Button = box.get("button")
		if btn != null and is_instance_valid(btn):
			btn.text = "%s [0]" % box.name
	_close_box_view()
	_hide_box_hover_preview()
	_drag_highlight_box_idx = -1
