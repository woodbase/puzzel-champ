extends GdUnitTestSuite

const GameStateScript := preload("res://scripts/game_state.gd")

var _temp_daily_path := "user://test_daily_result.json"


func before() -> void:
	_clear_temp_file()


func after() -> void:
	_clear_temp_file()


func test_record_daily_completion_persists_data() -> void:
	var gs := GameStateScript.new()
	gs._daily_result_path = _temp_daily_path

	gs.record_daily_completion(12.345, "2026-03-15")

	var gs2 := GameStateScript.new()
	gs2._daily_result_path = _temp_daily_path
	gs2._load_daily_result()

	var result := gs2.get_daily_result()
	assert_bool(gs2.has_completed_daily("2026-03-15")).is_true()
	assert_str(result.get("status", "")).is_equal("completed")
	assert_str(result.get("date", "")).is_equal("2026-03-15")
	assert_float(result.get("time", 0.0)).is_equal(snappedf(12.345, 0.001))


func test_has_completed_daily_checks_date_match() -> void:
	var gs := GameStateScript.new()
	gs._daily_result_path = _temp_daily_path

	gs.record_daily_completion(8.0, "2026-03-15")

	assert_bool(gs.has_completed_daily("2026-03-16")).is_false()
	assert_bool(gs.has_completed_daily("2026-03-15")).is_true()


func _clear_temp_file() -> void:
	if FileAccess.file_exists(_temp_daily_path):
		var abs := ProjectSettings.globalize_path(_temp_daily_path)
		DirAccess.remove_absolute(abs)
