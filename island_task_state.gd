extends RefCounted

class_name IslandTaskState

const IslandTaskData = preload("res://island_task_data.gd")
const SAVE_PATH: String = "user://island_task_state.json"


static func is_task_complete(task_id: String) -> bool:
	var completed: Array = _get_completed_ids()
	return task_id in completed


static func complete_task(task_id: String) -> void:
	var state: Dictionary = _load_state()
	var completed: Array = state.get("completed", [])
	if task_id in completed:
		return
	completed.append(task_id)
	state["completed"] = completed
	_save_state(state)


static func get_completed_count() -> int:
	return _get_completed_ids().size()


static func core_tasks_complete() -> bool:
	for task_id in IslandTaskData.core_task_ids():
		if not is_task_complete(task_id):
			return false
	return true


static func all_complete() -> bool:
	for task in IslandTaskData.TASKS:
		var task_id: String = task.get("id", "") as String
		if not is_task_complete(task_id):
			return false
	return true


static func is_ending_seen() -> bool:
	var state: Dictionary = _load_state()
	return bool(state.get("ending_seen", false))


static func mark_ending_seen() -> void:
	var state: Dictionary = _load_state()
	state["ending_seen"] = true
	_save_state(state)


static func _get_completed_ids() -> Array:
	var state: Dictionary = _load_state()
	var raw: Variant = state.get("completed", [])
	if raw is Array:
		return raw as Array
	return []


static func _load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	return data if data is Dictionary else {}


static func _save_state(state: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state))
