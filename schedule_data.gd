extends Node

## 日程数据：内置 JSON + 联网缓存合并。活动/任务可复用同一套远程 JSON 格式。

signal events_changed

const BUNDLED_PATH := "res://data/schedule.json"
const CACHE_PATH := "user://schedule_events_cache.json"

var _events: Array[Dictionary] = []
var _events_by_date: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_events = _load_events_from_path(BUNDLED_PATH)
	var cached: Array[Dictionary] = _load_events_from_path(CACHE_PATH)
	if not cached.is_empty():
		_events = _merge_event_lists(_events, cached)
	_rebuild_date_index()
	events_changed.emit()


func apply_remote_payload(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var remote_events: Array = payload.get("events", []) as Array
	if remote_events.is_empty():
		return

	var file: FileAccess = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()

	reload()


func get_all_events() -> Array[Dictionary]:
	return _events.duplicate() as Array[Dictionary]


func get_events_on_date(year: int, month: int, day: int) -> Array[Dictionary]:
	var key := _date_key(year, month, day)
	if not _events_by_date.has(key):
		return [] as Array[Dictionary]
	return (_events_by_date[key] as Array[Dictionary]).duplicate()


func has_events_on_date(year: int, month: int, day: int) -> bool:
	return not get_events_on_date(year, month, day).is_empty()


func get_events_in_month(year: int, month: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _events:
		var parts: PackedStringArray = str(event.get("date", "")).split("-")
		if parts.size() != 3:
			continue
		if int(parts[0]) == year and int(parts[1]) == month:
			result.append(event)
	return result


func _rebuild_date_index() -> void:
	_events_by_date.clear()
	for event in _events:
		var date_str: String = str(event.get("date", ""))
		if date_str.is_empty():
			continue
		if not _events_by_date.has(date_str):
			_events_by_date[date_str] = [] as Array[Dictionary]
		(_events_by_date[date_str] as Array[Dictionary]).append(event)


func _load_events_from_path(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return [] as Array[Dictionary]

	var text: String = ""
	if path.begins_with("res://"):
		if not ResourceLoader.exists(path):
			return [] as Array[Dictionary]
		var file_res: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file_res == null:
			return [] as Array[Dictionary]
		text = file_res.get_as_text()
	else:
		if not FileAccess.file_exists(path):
			return [] as Array[Dictionary]
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return [] as Array[Dictionary]
		text = file.get_as_text()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return [] as Array[Dictionary]

	var events_raw: Array = (parsed as Dictionary).get("events", []) as Array
	var events: Array[Dictionary] = []
	for item in events_raw:
		if item is Dictionary:
			events.append(item)
	return events


func _merge_event_lists(base: Array[Dictionary], extra: Array[Dictionary]) -> Array[Dictionary]:
	var merged: Dictionary = {}
	for event in base:
		var id: String = str(event.get("id", ""))
		if id.is_empty():
			continue
		merged[id] = event
	for event in extra:
		var id: String = str(event.get("id", ""))
		if id.is_empty():
			continue
		merged[id] = event

	var result: Array[Dictionary] = []
	for id in merged.keys():
		result.append(merged[id] as Dictionary)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("date", "")) < str(b.get("date", ""))
	)
	return result


func _date_key(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]
