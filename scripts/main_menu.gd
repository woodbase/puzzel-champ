extends Control

const IMAGES_DIR := "user://images/"
const MIN_COLS := 2
const MAX_COLS := 10
const MIN_ROWS := 2
const MAX_ROWS := 10
const SUPPORTED_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]

var gallery_paths: Array[String] = []
var current_gallery_index: int = 0

@onready var gallery_container: HBoxContainer = $VBoxContainer/GalleryContainer
@onready var preview_image: TextureRect = $VBoxContainer/PreviewContainer/PreviewImage
@onready var prev_button: Button = $VBoxContainer/GalleryContainer/PrevButton
@onready var next_button: Button = $VBoxContainer/GalleryContainer/NextButton
@onready var image_counter_label: Label = $VBoxContainer/GalleryContainer/ImageCounterLabel
@onready var cols_spinbox: SpinBox = $VBoxContainer/SettingsContainer/ColsSpinBox
@onready var rows_spinbox: SpinBox = $VBoxContainer/SettingsContainer/RowsSpinBox
@onready var pieces_label: Label = $VBoxContainer/SettingsContainer/PiecesLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var import_button: Button = $VBoxContainer/ImportButton
@onready var no_images_label: Label = $VBoxContainer/NoImagesLabel


func _ready() -> void:
	_ensure_images_dir()
	_load_gallery()
	_update_ui()


func _ensure_images_dir() -> void:
	if not DirAccess.dir_exists_absolute(IMAGES_DIR):
		DirAccess.make_dir_absolute(IMAGES_DIR)


func _load_gallery() -> void:
	gallery_paths.clear()
	var dir := DirAccess.open(IMAGES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext: String = file_name.get_extension().to_lower()
			if ext in SUPPORTED_EXTENSIONS:
				gallery_paths.append(IMAGES_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	gallery_paths.sort()
	current_gallery_index = clampi(GameState.gallery_index, 0, maxi(gallery_paths.size() - 1, 0))


func _update_ui() -> void:
	var total: int = gallery_paths.size()
	var has_images: bool = total > 0

	no_images_label.visible = not has_images
	preview_image.visible = has_images
	gallery_container.visible = has_images
	start_button.disabled = not has_images

	if has_images:
		_show_image(current_gallery_index)
		image_counter_label.text = "%d / %d" % [current_gallery_index + 1, total]
		prev_button.disabled = current_gallery_index <= 0
		next_button.disabled = current_gallery_index >= total - 1

	_update_pieces_label()


func _show_image(index: int) -> void:
	if index < 0 or index >= gallery_paths.size():
		return
	var path: String = gallery_paths[index]
	var image := Image.load_from_file(path)
	if image == null:
		return
	preview_image.texture = ImageTexture.create_from_image(image)


func _update_pieces_label() -> void:
	var cols: int = int(cols_spinbox.value)
	var rows: int = int(rows_spinbox.value)
	var total: int = cols * rows
	pieces_label.text = "Pieces: %d" % total


func _on_prev_button_pressed() -> void:
	current_gallery_index = maxi(current_gallery_index - 1, 0)
	_update_ui()


func _on_next_button_pressed() -> void:
	var total: int = gallery_paths.size()
	current_gallery_index = mini(current_gallery_index + 1, total - 1)
	_update_ui()


func _on_cols_spinbox_value_changed(_value: float) -> void:
	_update_pieces_label()


func _on_rows_spinbox_value_changed(_value: float) -> void:
	_update_pieces_label()


func _on_start_button_pressed() -> void:
	if gallery_paths.is_empty():
		return
	var path: String = gallery_paths[current_gallery_index]
	var image := Image.load_from_file(path)
	if image == null:
		return
	GameState.image_texture = ImageTexture.create_from_image(image)
	GameState.image_path = path
	GameState.gallery_index = current_gallery_index
	GameState.cols = int(cols_spinbox.value)
	GameState.rows = int(rows_spinbox.value)
	get_tree().change_scene_to_file("res://scenes/puzzle_board.tscn")


func _on_import_button_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Image files"])
	dialog.files_selected.connect(_on_files_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.8)


func _on_files_selected(paths: PackedStringArray) -> void:
	var total: int = paths.size()
	for i: int in range(total):
		var src_path: String = paths[i]
		var file_name: String = src_path.get_file()
		var dst_path: String = IMAGES_DIR + file_name
		DirAccess.copy_absolute(src_path, dst_path)
	_load_gallery()
	_update_ui()
