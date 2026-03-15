extends RefCounted

## Returns a deterministic seed for the given ISO date (YYYY-MM-DD).
## When date_string is empty, the current system date is used.
static func get_daily_seed(date_string: String = "") -> int:
	var date := date_string
	if date.is_empty():
		date = Time.get_date_string_from_system()
	# Use abs(hash()) to avoid negative seeds while keeping determinism.
	return abs(hash(date))
