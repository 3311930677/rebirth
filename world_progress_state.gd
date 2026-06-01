extends RefCounted

class_name WorldProgressState

const SAVE_PATH := "user://world_progress_state.json"


static func mark_last_world(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var state: Dictionary = _load_state()
	state["last_world_scene"] = scene_path
	_save_state(state)


static func get_last_world_scene(default_scene: String = "") -> String:
	var state: Dictionary = _load_state()
	var scene_path: String = state.get("last_world_scene", default_scene) as String
	if scene_path.is_empty():
		return default_scene
	return scene_path


static func save_world_snapshot(scene_path: String, snapshot: Dictionary) -> void:
	if scene_path.is_empty():
		return
	var state: Dictionary = _load_state()
	var worlds: Dictionary = state.get("worlds", {}) as Dictionary
	worlds[scene_path] = snapshot
	state["worlds"] = worlds
	state["last_world_scene"] = scene_path
	_save_state(state)


static func get_world_snapshot(scene_path: String) -> Dictionary:
	if scene_path.is_empty():
		return {}
	var state: Dictionary = _load_state()
	var worlds: Dictionary = state.get("worlds", {}) as Dictionary
	var raw: Variant = worlds.get(scene_path, {})
	return raw if raw is Dictionary else {}


static func clear_world_snapshot(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var state: Dictionary = _load_state()
	var worlds: Dictionary = state.get("worlds", {}) as Dictionary
	if worlds.has(scene_path):
		worlds.erase(scene_path)
		state["worlds"] = worlds
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
