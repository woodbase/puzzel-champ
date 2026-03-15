extends GdUnitTestSuite

const DailySeed := preload("res://scripts/daily_seed.gd")


func test_same_date_returns_same_seed() -> void:
	var seed_a := DailySeed.get_daily_seed("2026-03-15")
	var seed_b := DailySeed.get_daily_seed("2026-03-15")

	assert_int(seed_a).is_equal(seed_b)


func test_different_dates_return_different_seeds() -> void:
	var seed_today := DailySeed.get_daily_seed("2026-03-15")
	var seed_next := DailySeed.get_daily_seed("2026-03-16")

	assert_int(seed_today).is_not_equal(seed_next)
