extends GdUnitTestSuite

## Verification tests for mobile sub-issues.
## Covers MOBILE-03 (Drag Threshold), MOBILE-07 (Touch Gesture Support),
## MOBILE-08 (Piece Snap Feedback), and MOBILE-09 (Mobile Performance Pass).
## MOBILE-01, 02, 04, 05, 06 operate at the PuzzleBoard/UIScale level and
## are verified through integration; MOBILE-10 is covered by the completion
## overlay built in _build_complete_overlay().

const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")


## Shared helper – creates a PuzzlePiece parented under a Node2D so
## to_global() works with an identity transform (local == global).
func _make_piece(target: Vector2, snap_dist: float) -> Area2D:
	var parent := Node2D.new()
	add_child(parent)
	auto_free(parent)

	var piece: Area2D = PIECE_SCENE.instantiate()
	parent.add_child(piece)
	piece.correct_position = target
	piece.snap_distance    = snap_dist
	return piece


# ─── MOBILE-03: Drag Threshold ────────────────────────────────────────────────

## Acceptance criterion: Tapping a piece (movement < DRAG_THRESHOLD) must NOT
## move it.  The drag state must remain pending rather than active.
## Uses InputEventScreenDrag which applies position directly (unlike
## InputEventMouseMotion which calls get_global_mouse_position() internally).
func test_mobile03_tap_below_threshold_does_not_start_drag() -> void:
	var piece := _make_piece(Vector2(200.0, 150.0), 50.0)

	# Simulate a touch press: record the press start and mark pending.
	piece._press_start = Vector2(100.0, 100.0)
	piece._pending_drag = true

	# Synthesise a touch-drag event that moves LESS than DRAG_THRESHOLD.
	var drag := InputEventScreenDrag.new()
	drag.index    = 0
	drag.position = Vector2(100.0 + piece.DRAG_THRESHOLD * 0.5, 100.0)
	piece._input(drag)

	# Drag must NOT have started – _pending_drag still true, _dragging false.
	assert_bool(piece._pending_drag).is_true()
	assert_bool(piece._dragging).is_false()


## Acceptance criterion: Intentional dragging (movement ≥ DRAG_THRESHOLD)
## must start the drag so the piece can be moved.
func test_mobile03_movement_at_threshold_starts_drag() -> void:
	var piece := _make_piece(Vector2(200.0, 150.0), 50.0)

	# Simulate a touch press.
	piece._press_start = Vector2(100.0, 100.0)
	piece._pending_drag = true

	# Synthesise a touch-drag event that exceeds DRAG_THRESHOLD.
	var drag := InputEventScreenDrag.new()
	drag.index    = 0
	drag.position = Vector2(100.0 + piece.DRAG_THRESHOLD + 1.0, 100.0)
	piece._input(drag)

	# The drag must have started.
	assert_bool(piece._dragging).is_true()


## DRAG_THRESHOLD constant must be 10.0 px as specified in MOBILE-03.
func test_mobile03_drag_threshold_value_is_ten_pixels() -> void:
	var piece := _make_piece(Vector2.ZERO, 50.0)
	assert_float(piece.DRAG_THRESHOLD).is_equal(10.0)


# ─── MOBILE-07: Touch Gesture Support ────────────────────────────────────────

## Acceptance criterion: A drag event arriving from a different touch finger
## than the one that started the drag must be completely ignored.
func test_mobile07_touch_drag_from_wrong_finger_is_ignored() -> void:
	var piece := _make_piece(Vector2(200.0, 150.0), 50.0)

	# Start a drag on finger 0 at a known position.
	var start_pos := Vector2(300.0, 300.0)
	piece.global_position   = start_pos
	piece._dragging         = true
	piece._drag_offset      = Vector2.ZERO
	piece._drag_touch_index = 0

	# Send a drag event from finger 1 pointing to a completely different place.
	var drag := InputEventScreenDrag.new()
	drag.index    = 1
	drag.position = Vector2(600.0, 600.0)
	piece._input(drag)

	# The piece must not have moved.
	assert_vector2(piece.global_position).is_equal(start_pos)


## Acceptance criterion: A drag event from the CORRECT touch finger must move
## the piece, confirming that single-finger piece dragging still works.
func test_mobile07_touch_drag_from_correct_finger_moves_piece() -> void:
	var piece := _make_piece(Vector2(200.0, 150.0), 200.0)

	# Start a drag on finger 0.
	piece._press_start      = Vector2(100.0, 100.0)
	piece._pending_drag     = true
	piece._drag_touch_index = 0

	# Send a ScreenDrag from the same finger with enough movement to start dragging.
	var drag := InputEventScreenDrag.new()
	drag.index    = 0
	drag.position = Vector2(100.0 + piece.DRAG_THRESHOLD + 5.0, 100.0)
	piece._input(drag)

	# Drag must have started.
	assert_bool(piece._dragging).is_true()


## Acceptance criterion: cancel_drag must clear all drag state so that a
## subsequent two-finger gesture can proceed without a stale dragging piece.
## (Full gesture coordination happens at PuzzleBoard level; this test verifies
## the prerequisite: the piece exits drag state cleanly.)
func test_mobile07_cancel_drag_allows_gesture_takeover() -> void:
	var piece := _make_piece(Vector2(200.0, 150.0), 50.0)

	# Simulate an active drag.
	piece._dragging         = true
	piece._drag_touch_index = 0
	piece._original_z_index = 0
	piece.z_index           = 10

	piece.cancel_drag()

	# After cancellation the piece must not be dragging and must be droppable
	# by a two-finger gesture handler.
	assert_bool(piece._dragging).is_false()
	assert_bool(piece._pending_drag).is_false()
	assert_int(piece._drag_touch_index).is_equal(-1)


# ─── MOBILE-08: Piece Snap Feedback ──────────────────────────────────────────

## Acceptance criterion: piece_placed signal must be emitted on snap so that
## PuzzleBoard can play audio/haptic feedback.
func test_mobile08_snap_emits_piece_placed_signal() -> void:
	var target := Vector2(200.0, 150.0)
	var piece  := _make_piece(target, 50.0)

	monitor_signals(piece)

	piece.global_position = target + Vector2(10.0, 0.0)
	piece._dragging = true
	piece._end_drag()

	assert_signal(piece).is_emitted("piece_placed")


## Acceptance criterion: after snapping the piece must be locked and not
## moveable again (input_pickable = false).
func test_mobile08_snapped_piece_is_locked_and_non_interactive() -> void:
	var target := Vector2(100.0, 80.0)
	var piece  := _make_piece(target, 60.0)

	piece.global_position = target + Vector2(20.0, 0.0)
	piece._dragging = true
	piece._end_drag()

	assert_bool(piece.is_locked).is_true()
	assert_bool(piece.input_pickable).is_false()


## Acceptance criterion: snap feedback must work even with visual feedback
## disabled (GameState.feedback_visual = false).
func test_mobile08_snap_works_with_all_feedback_disabled() -> void:
	var saved_visual := GameState.feedback_visual
	var saved_audio  := GameState.feedback_audio
	var saved_haptic := GameState.feedback_haptic
	GameState.feedback_visual = false
	GameState.feedback_audio  = false
	GameState.feedback_haptic = false

	var target := Vector2(150.0, 120.0)
	var piece  := _make_piece(target, 60.0)

	piece.global_position = target + Vector2(15.0, 0.0)
	piece._dragging = true
	piece._end_drag()

	GameState.feedback_visual = saved_visual
	GameState.feedback_audio  = saved_audio
	GameState.feedback_haptic = saved_haptic

	assert_bool(piece.is_locked).is_true()
	assert_vector2(piece.global_position).is_equal(target)


# ─── MOBILE-09: Mobile Performance Pass ──────────────────────────────────────

## Acceptance criterion: sub-pixel drag movements must be filtered out to
## avoid redundant position updates (MIN_DRAG_MOVE_SQ threshold).
## Uses InputEventScreenDrag since it passes position directly to _update_drag.
func test_mobile09_subpixel_drag_does_not_update_position() -> void:
	var piece := _make_piece(Vector2(200.0, 150.0), 50.0)

	piece._dragging         = true
	piece._drag_offset      = Vector2.ZERO
	piece._drag_touch_index = 0
	var start := Vector2(100.0, 100.0)
	piece.global_position  = start

	# Move less than sqrt(MIN_DRAG_MOVE_SQ) = 0.5 px – should be filtered.
	var drag := InputEventScreenDrag.new()
	drag.index    = 0
	drag.position = start + Vector2(0.3, 0.3)  # distance_sq = 0.18 < 0.25
	piece._input(drag)

	# Position must not have changed.
	assert_vector2(piece.global_position).is_equal(start)


## MIN_DRAG_MOVE_SQ must be 0.25 (√0.25 ≈ 0.5 px threshold) as implemented.
func test_mobile09_min_drag_move_sq_value() -> void:
	var piece := _make_piece(Vector2.ZERO, 50.0)
	assert_float(piece.MIN_DRAG_MOVE_SQ).is_equal(0.25)
