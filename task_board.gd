extends Control

const EscExitHelper = preload("res://esc_exit_helper.gd")

@export var background_path: String = "res://Sprite/task inside.png"
@export var task_pool_path: String = "res://task_pool.txt"
@export var font_path: String = "res://HYPixel11pxU-2.ttf"
@export var return_scene_path: String = "res://node_2d.tscn"
@export var state_save_path: String = "user://task_state.json"
@export var tasks_per_day: int = 2

@onready var _background: TextureRect = $Background
@onready var _title: Label = $TaskPanel/Title
@onready var _task_1: Label = $TaskPanel/Task1
@onready var _task_2: Label = $TaskPanel/Task2
@onready var _hint: Label = $TaskPanel/Hint
@onready var _panel: Panel = $TaskPanel

var _task_pool: Array[String] = []
var _today_indices: Array[int] = []
var _today_completed: Array[bool] = []
var _state: Dictionary = {}
var _esc_confirm_pending := false

func _ready() -> void:
	_apply_background()
	_apply_font()
	_initialize_daily_tasks()
	_refresh_task_labels()
	_play_intro_effect()
	_play_title_breathing()

func _unhandled_input(event: InputEvent) -> void:
	if EscExitHelper.handle_input(
		event,
		_esc_confirm_pending,
		return_scene_path,
		get_tree(),
		_set_esc_confirm_pending,
		_save_state
	):
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_1, KEY_KP_1:
				_toggle_task_done(0)
			KEY_2, KEY_KP_2:
				_toggle_task_done(1)

func _apply_background() -> void:
	var tex: Texture2D = load(background_path) as Texture2D
	_background.texture = tex

func _apply_font() -> void:
	var font: FontFile = load(font_path) as FontFile
	if font == null:
		return

	for label in [_title, _task_1, _task_2, _hint]:
		label.add_theme_font_override("font", font)

func _initialize_daily_tasks() -> void:
	_task_pool = _load_task_pool()
	if _task_pool.is_empty():
		_task_pool = ["任务一：暂无", "任务二：暂无", "任务三：暂无"]

	_state = _load_state()
	_ensure_state_integrity()
	var today: String = Time.get_date_string_from_system()

	var saved_date: String = str(_state.get("date", ""))
	if saved_date != today:
		_today_indices = _draw_next_indices(tasks_per_day)
		_today_completed = []
		for _i in range(_today_indices.size()):
			_today_completed.append(false)
		_state["date"] = today
		_state["today_indices"] = _today_indices
		_state["today_completed"] = _today_completed
	else:
		_today_indices = _sanitize_indices(_state.get("today_indices", []))
		_today_completed = _sanitize_completed(_state.get("today_completed", []), _today_indices.size())
		if _today_indices.is_empty():
			_today_indices = _draw_next_indices(tasks_per_day)
			_today_completed = _sanitize_completed([], _today_indices.size())
		_state["today_indices"] = _today_indices
		_state["today_completed"] = _today_completed

	_save_state()

func _refresh_task_labels() -> void:
	var defaults: Array[String] = ["任务一：暂无", "任务二：暂无"]
	var labels: Array[Label] = [_task_1, _task_2]
	for i in range(labels.size()):
		var task_text: String = defaults[i]
		if i < _today_indices.size():
			var idx: int = _today_indices[i]
			if idx >= 0 and idx < _task_pool.size():
				task_text = _task_pool[idx]
		var done: bool = i < _today_completed.size() and _today_completed[i]
		var prefix: String = "[x] " if done else "[ ] "
		labels[i].text = str(i + 1) + ". " + prefix + task_text
		labels[i].modulate = Color(0.78, 1.0, 0.8, 1.0) if done else Color(1, 1, 1, 1)

	var done_count: int = 0
	for flag in _today_completed:
		if flag:
			done_count += 1
	_hint.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		"今日进度：%d/%d   (按 1 / 2 勾选，Esc 返回)" % [done_count, _today_indices.size()],
		"再按 Enter 确认返回主房间"
	)

func _set_esc_confirm_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_refresh_task_labels()

func _load_task_pool() -> Array[String]:
	var tasks: Array[String] = []
	var file: FileAccess = FileAccess.open(task_pool_path, FileAccess.READ)
	if file == null:
		return tasks

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		tasks.append(line)
	return tasks

func _ensure_state_integrity() -> void:
	var expected_size: int = _task_pool.size()
	var order: Array = _get_array_state("order")
	var cursor: int = int(_state.get("cursor", 0))

	if order.size() != expected_size:
		order = []
		for i in range(expected_size):
			order.append(i)
		order.shuffle()
		cursor = 0
	else:
		var seen: Dictionary = {}
		var valid: bool = true
		for item in order:
			var idx: int = int(item)
			if idx < 0 or idx >= expected_size or seen.has(idx):
				valid = false
				break
			seen[idx] = true
		if not valid:
			order = []
			for i in range(expected_size):
				order.append(i)
			order.shuffle()
			cursor = 0

	if cursor < 0 or cursor >= maxi(1, expected_size):
		cursor = 0

	_state["order"] = order
	_state["cursor"] = cursor

func _draw_next_indices(count: int) -> Array[int]:
	var indices: Array[int] = []
	if _task_pool.is_empty():
		return indices

	var order: Array = _get_array_state("order")
	var cursor: int = int(_state.get("cursor", 0))

	for _n in range(count):
		if order.is_empty():
			for i in range(_task_pool.size()):
				order.append(i)
			order.shuffle()
			cursor = 0

		if cursor >= order.size():
			order.shuffle()
			cursor = 0

		indices.append(int(order[cursor]))
		cursor += 1

	_state["order"] = order
	_state["cursor"] = cursor
	return indices

func _get_array_state(key: String) -> Array:
	var raw: Variant = _state.get(key, [])
	if raw is Array:
		return raw as Array
	return []

func _sanitize_indices(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for item in raw as Array:
			var idx: int = int(item)
			if idx >= 0 and idx < _task_pool.size():
				out.append(idx)
	return out

func _sanitize_completed(raw: Variant, size_needed: int) -> Array[bool]:
	var out: Array[bool] = []
	for i in range(size_needed):
		var flag: bool = false
		if raw is Array and i < (raw as Array).size():
			flag = bool((raw as Array)[i])
		out.append(flag)
	return out

func _toggle_task_done(task_idx: int) -> void:
	if task_idx < 0 or task_idx >= _today_completed.size():
		return
	_today_completed[task_idx] = not _today_completed[task_idx]
	_state["today_completed"] = _today_completed
	_save_state()
	_refresh_task_labels()

func _load_state() -> Dictionary:
	var file: FileAccess = FileAccess.open(state_save_path, FileAccess.READ)
	if file == null:
		return {}

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

func _save_state() -> void:
	var file: FileAccess = FileAccess.open(state_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_state))

func _play_intro_effect() -> void:
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.95, 0.95)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.25)

func _play_title_breathing() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "modulate", Color(1, 0.97, 0.8, 1), 0.8)
	tween.tween_property(_title, "modulate", Color(1, 1, 1, 1), 0.8)
