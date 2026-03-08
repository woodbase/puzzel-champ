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
var _generator: Object = null

## HUD label showing piece progress.
var _counter_label: Label = null

## Fullscreen overlay shown when the puzzle is complete.
var _complete_overlay: Control = null

## Guard flag: prevents overlapping rebuild calls.
var _building: bool = false

## Currently selected piece shape key (mirrors GameState.piece_shape).
var _piece_shape: String = "jigsaw"

## AudioStreamPlayer used to play the pickup sound effect.
var _pickup_player: AudioStreamPlayer = null

## AudioStreamPlayer used to play the snap sound effect.
var _snap_player: AudioStreamPlayer = null

## AudioStreamPlayer used to play the puzzle-completion fanfare.
var _complete_player: AudioStreamPlayer = null

## The settings panel overlay (visibility toggled by the settings button).
var _settings_panel: Control = null


func _ready() -> void:
	_generator = PuzzleGeneratorScript.new()
	_pickup_player = _create_pickup_audio_player()
	add_child(_pickup_player)
	_snap_player = _create_snap_audio_player()
	add_child(_snap_player)
	_complete_player = _create_complete_audio_player()
	add_child(_complete_player)
	_music_player = _create_music_player()
	add_child(_music_player)

	# GameState overrides the editor export vars when coming from the menu.
	if GameState.image_texture != null:
		source_texture = GameState.image_texture
		cols           = GameState.cols
		rows           = GameState.rows
		_piece_shape   = GameState.piece_shape

	_build_hud()

	if source_texture != null:
		_build_puzzle()
	else:
		_show_no_image_message()

	if GameState.music_enabled:
		_music_player.play()


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

	var settings_btn := _make_hud_button("⚙")
	settings_btn.pressed.connect(_toggle_settings_panel)
	settings_btn.tooltip_text = "Feedback settings"
	hbox.add_child(settings_btn)

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
	_build_settings_panel()
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


## Builds a floating settings panel anchored below the HUD bar.
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
	panel.offset_left   = -220
	panel.offset_right  = 0
	panel.offset_top    = HUD_H + 4
	panel.offset_bottom = HUD_H + 4 + 200
	panel.visible = false
	_hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.75, 0.65, 0.95))
	vbox.add_child(title)

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
		"Sound effects",
		GameState.feedback_audio,
		func(on: bool) -> void: GameState.feedback_audio = on
	))
	vbox.add_child(_make_feedback_toggle(
		"Vibration",
		GameState.feedback_haptic,
		func(on: bool) -> void: GameState.feedback_haptic = on
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


## Toggles the settings panel's visibility.
func _toggle_settings_panel() -> void:
	if _settings_panel != null:
		_settings_panel.visible = not _settings_panel.visible


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

	var complete_title_lbl := Label.new()
	complete_title_lbl.text = "Puzzle Complete!"
	complete_title_lbl.add_theme_font_size_override("font_size", 40)
	complete_title_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.98))
	complete_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(complete_title_lbl)

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

	var piece_data_array: Array = _generator.generate_edges(cols, rows)
	_total_pieces  = piece_data_array.size()
	_placed_pieces = 0
	_update_counter()

	var viewport_size := get_viewport_rect().size

	# Resolve the shape enum value from the string key.
	var shape_enum: int = PuzzleGeneratorScript.PieceShape.JIGSAW
	if _piece_shape == "square":
		shape_enum = PuzzleGeneratorScript.PieceShape.SQUARE

	for pd in piece_data_array:
		var col: int = pd.grid_pos.x
		var row: int = pd.grid_pos.y

		# Generate polygon and masked texture for this piece.
		var polygon: PackedVector2Array = _generator.generate_piece_polygon(pd, piece_size, shape_enum)
		var region  := Rect2i(col * piece_size, row * piece_size, piece_size, piece_size)
		var texture: ImageTexture = _generator.create_piece_texture(image, region, polygon, shape_enum)

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
		piece.piece_picked_up.connect(on_piece_picked_up)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _update_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "Pieces: %d / %d" % [_placed_pieces, _total_pieces]


## Called by each PuzzlePiece when it snaps into place.
func on_piece_placed() -> void:
	_placed_pieces += 1
	_update_counter()
	if GameState.feedback_audio and _snap_player != null:
		_snap_player.play()
	if _placed_pieces >= _total_pieces and _total_pieces > 0:
		_show_complete()


## Called by each PuzzlePiece when the player picks it up.
func on_piece_picked_up() -> void:
	if GameState.feedback_audio and _pickup_player != null:
		_pickup_player.play()


## Displays the completion overlay and plays the completion fanfare.
func _show_complete() -> void:
	if _complete_overlay != null:
		_complete_overlay.visible = true
	if GameState.feedback_audio and _complete_player != null:
		_complete_player.play()


## Creates and returns an AudioStreamPlayer loaded with a generated pickup sound.
func _create_pickup_audio_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = -10.0
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
	player.volume_db = -6.0
	player.stream = _generate_snap_sound()
	return player


## Creates and returns an AudioStreamPlayer loaded with looping background music.
func _create_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = -18.0
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
	player.volume_db = -3.0
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
	if _music_player != null:
		_music_player.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Clears all pieces and rebuilds the puzzle with the same image.
func _on_new_puzzle() -> void:
	if _building:
		return
	_building = true

	if _complete_overlay != null:
		_complete_overlay.visible = false

	if _complete_player != null:
		_complete_player.stop()

	for piece in get_tree().get_nodes_in_group("puzzle_pieces"):
		piece.queue_free()

	_placed_pieces = 0
	_total_pieces  = 0
	_update_counter()

	# Wait one frame so queue_free calls have resolved before rebuilding.
	await get_tree().process_frame
	_build_puzzle()
	_building = false
