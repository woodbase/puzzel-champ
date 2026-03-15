extends RefCounted

## Returns a deterministic integer seed for the given date (YYYY-MM-DD).
## When no date is provided, the current system date is used.
static func get_daily_seed(date_string: String = "") -> int:
	var date_str := date_string if not date_string.is_empty() else Time.get_date_string_from_system()
	return int(hash(date_str))
