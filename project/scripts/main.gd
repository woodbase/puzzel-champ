extends Control

@onready var _load_button: Button = $VBoxContainer/TopBar/LoadImageButton
@onready var _difficulty_option: OptionButton = $VBoxContainer/TopBar/DifficultyOption
@onready var _status_label: Label = $VBoxContainer/TopBar/StatusLabel
@onready var _puzzle_board = $VBoxContainer/PuzzleBoard
@onready var _file_dialog: FileDialog = $FileDialog


func _ready() -> void:
	_difficulty_option.add_item("3x3")
	_difficulty_option.add_item("4x4")
	_difficulty_option.add_item("6x6")
	_difficulty_option.add_item("8x8")
	_difficulty_option.selected = 1  # default: 4x4

	_load_button.pressed.connect(_on_load_button_pressed)
	_file_dialog.file_selected.connect(_on_file_selected)
	_puzzle_board.puzzle_complete.connect(_on_puzzle_complete)


func _on_load_button_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.75)


func _on_file_selected(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null:
		_status_label.text = "Error: could not load image."
		return

	var texture := ImageTexture.create_from_image(image)
	var cols_rows := _get_difficulty_size()
	_puzzle_board.setup_puzzle(texture, cols_rows)
	_status_label.text = "Pieces: %d  |  Good luck!" % (cols_rows * cols_rows)


func _get_difficulty_size() -> int:
	match _difficulty_option.selected:
		0: return 3
		1: return 4
		2: return 6
		3: return 8
	return 4


func _on_puzzle_complete() -> void:
	_status_label.text = "Congratulations! Puzzle complete! 🎉"
