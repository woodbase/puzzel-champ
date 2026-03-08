extends Control

## Emitted when every piece has been correctly placed.
signal puzzle_complete

const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")
const PuzzleGeneratorScript := preload("res://scripts/puzzle_generator.gd")

var _pieces: Array = []
var _grid_size: int = 0
var _piece_size: Vector2 = Vector2.ZERO
var _puzzle_offset: Vector2 = Vector2.ZERO
var _placed_count: int = 0

## Whether visual snap feedback is enabled.
var feedback_visual: bool = true

## Whether audio snap feedback is enabled.
var feedback_audio: bool = true

## Whether haptic snap feedback is enabled.
var feedback_haptic: bool = true

## AudioStreamPlayer used to play the pickup sound effect.
var _pickup_player: AudioStreamPlayer = null

## AudioStreamPlayer used to play the snap sound effect.
var _snap_player: AudioStreamPlayer = null


func _ready() -> void:
	_pickup_player = _create_pickup_audio_player()
	add_child(_pickup_player)
	_snap_player = _create_snap_audio_player()
	add_child(_snap_player)


## Clears the current puzzle and builds a new one from the given texture.
func setup_puzzle(
		texture: ImageTexture,
		cols_rows: int,
		piece_shape: int = PuzzleGeneratorScript.PieceShape.SQUARE,
		allow_rotation: bool = false
	) -> void:
	for piece in _pieces:
		piece.queue_free()
	_pieces.clear()
	_placed_count = 0
	_grid_size = cols_rows

	# Fit the puzzle grid inside 90 % of the board, preserving image aspect ratio.
	var board_size := size
	var img_w := float(texture.get_width())
	var img_h := float(texture.get_height())
	var img_aspect := img_w / img_h if img_h > 0.0 else 1.0
	var board_aspect := board_size.x / board_size.y if board_size.y > 0.0 else 1.0

	var fit_w: float
	var fit_h: float
	if img_aspect > board_aspect:
		fit_w = board_size.x * 0.9
		fit_h = fit_w / img_aspect
	else:
		fit_h = board_size.y * 0.9
		fit_w = fit_h * img_aspect

	_piece_size = Vector2(fit_w / cols_rows, fit_h / cols_rows)
	_puzzle_offset = Vector2(
		(board_size.x - fit_w) * 0.5,
		(board_size.y - fit_h) * 0.5
	)

	var textures: Array[ImageTexture] = PuzzleGeneratorScript.generate_pieces(texture, cols_rows, piece_shape)

	for i in range(textures.size()):
		var col := i % cols_rows
		var row := i / cols_rows
		var correct_pos := _puzzle_offset + Vector2(col * _piece_size.x, row * _piece_size.y)

		var piece: Control = PIECE_SCENE.instantiate()
		add_child(piece)
		piece.setup(textures[i], Vector2i(col, row), correct_pos, _piece_size, allow_rotation)
		piece.feedback_visual = feedback_visual
		piece.feedback_haptic = feedback_haptic
		piece.position = Vector2(
			randf_range(0.0, board_size.x - _piece_size.x),
			randf_range(0.0, board_size.y - _piece_size.y)
		)
		piece.piece_placed.connect(_on_piece_placed)
		piece.piece_picked_up.connect(_on_piece_picked_up)
		_pieces.append(piece)

	queue_redraw()


func _on_piece_placed() -> void:
	_placed_count += 1
	queue_redraw()
	if feedback_audio and _snap_player != null:
		_snap_player.play()
	if _placed_count >= _pieces.size():
		puzzle_complete.emit()


## Called by each PuzzlePiece when the player picks it up.
func _on_piece_picked_up() -> void:
	if feedback_audio and _pickup_player != null:
		_pickup_player.play()


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
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format    = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate  = sample_rate
	stream.stereo    = false
	stream.data      = data
	return stream


func _draw() -> void:
	# Dark background.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.15))

	if _grid_size > 0 and _piece_size != Vector2.ZERO:
		# Guide grid showing target positions.
		for row in range(_grid_size):
			for col in range(_grid_size):
				var rect := Rect2(
					_puzzle_offset + Vector2(col * _piece_size.x, row * _piece_size.y),
					_piece_size
				)
				draw_rect(rect, Color(0.35, 0.35, 0.35, 0.8), false, 1.5)
