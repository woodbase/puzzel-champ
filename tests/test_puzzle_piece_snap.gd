extends GdUnitTestSuite

const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")


## Creates a puzzle piece as a child of a plain Node2D so that to_global()
## in _end_drag() works with an identity transform (local == global).
func _make_piece(target: Vector2, snap_dist: float) -> Area2D:
	var parent := Node2D.new()
	add_child(parent)
	auto_free(parent)

	var piece: Area2D = PIECE_SCENE.instantiate()
	parent.add_child(piece)
	piece.correct_position = target
	piece.snap_distance = snap_dist
	return piece


## A piece dropped within snap_distance must land exactly on the target with
## no visible offset, regardless of the snap_to_board preference.
func test_snap_aligns_to_exact_position_within_threshold() -> void:
	var target := Vector2(200.0, 150.0)
	var piece := _make_piece(target, 50.0)

	# Place the piece 30 px from target (inside the 50 px threshold).
	piece.global_position = target + Vector2(30.0, 0.0)
	piece._dragging = true
	piece._end_drag()

	assert_bool(piece.is_locked).is_true()
	assert_vector2(piece.global_position).is_equal(target)


## The exact-position snap must happen even when snap_to_board is disabled,
## so that no visible offset is left after a piece is locked.
func test_snap_aligns_even_when_snap_to_board_disabled() -> void:
	var saved := GameState.snap_to_board
	GameState.snap_to_board = false

	var target := Vector2(100.0, 80.0)
	var piece := _make_piece(target, 50.0)

	piece.global_position = target + Vector2(20.0, 15.0)
	piece._dragging = true
	piece._end_drag()

	GameState.snap_to_board = saved

	assert_bool(piece.is_locked).is_true()
	assert_vector2(piece.global_position).is_equal(target)


## A piece dropped outside snap_distance must not be locked.
func test_no_snap_outside_threshold() -> void:
	var target := Vector2(100.0, 80.0)
	var piece := _make_piece(target, 50.0)

	# Drop 100 px away — well outside the 50 px threshold.
	piece.global_position = target + Vector2(100.0, 0.0)
	piece._dragging = true
	piece._end_drag()

	assert_bool(piece.is_locked).is_false()
	# Position must stay at where it was dropped, not moved to the target.
	assert_vector2(piece.global_position).is_not_equal(target)


## A locked piece must have input disabled so it cannot be accidentally moved.
func test_locked_piece_has_input_disabled() -> void:
	var target := Vector2(50.0, 50.0)
	var piece := _make_piece(target, 80.0)

	# Snap the piece into place.
	piece.global_position = target + Vector2(10.0, 0.0)
	piece._dragging = true
	piece._end_drag()

	# Both flags must be set so the piece cannot be picked up again.
	assert_bool(piece.is_locked).is_true()
	assert_bool(piece.input_pickable).is_false()
