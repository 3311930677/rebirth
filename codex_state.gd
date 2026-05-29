extends RefCounted

class_name CodexState

const SAVE_PATH := "user://codex_state.json"


static func is_diary_unlocked() -> bool:
	var state: Dictionary = _load_state()
	return bool(state.get("diary_unlocked", false))


static func unlock_diary() -> void:
	var state: Dictionary = _load_state()
	state["diary_unlocked"] = true
	_save_state(state)


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
