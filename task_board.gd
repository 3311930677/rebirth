extends Control

const EscExitHelper = preload("res://esc_exit_helper.gd")
const IslandTaskData = preload("res://island_task_data.gd")
const IslandTaskState = preload("res://island_task_state.gd")

@export var background_path: String = "res://Sprite/task inside.png"
@export var font_path: String = "res://HYPixel11pxU-2.ttf"
@export var return_scene_path: String = "res://node_2d.tscn"

@onready var _background: TextureRect = $Background
@onready var _title: Label = $TaskPanel/Title
@onready var _task_1: Label = $TaskPanel/Task1
@onready var _task_2: Label = $TaskPanel/Task2
@onready var _task_3: Label = $TaskPanel/Task3
@onready var _task_4: Label = $TaskPanel/Task4
@onready var _task_5: Label = $TaskPanel/Task5
@onready var _hint: Label = $TaskPanel/Hint
@onready var _panel: Panel = $TaskPanel

var _esc_confirm_pending: bool = false


func _ready() -> void:
	_apply_background()
	_apply_font()
	_title.text = "—  星途岛 · 五大任务  —"
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
		Callable(),
		self
	):
		return


func _apply_background() -> void:
	var tex: Texture2D = load(background_path) as Texture2D
	_background.texture = tex


func _apply_font() -> void:
	var font: FontFile = load(font_path) as FontFile
	if font == null:
		return

	for label: Label in [_title, _task_1, _task_2, _task_3, _task_4, _task_5, _hint]:
		label.add_theme_font_override("font", font)


func _refresh_task_labels() -> void:
	var labels: Array[Label] = [_task_1, _task_2, _task_3, _task_4, _task_5]
	for i in range(labels.size()):
		var task: Dictionary = IslandTaskData.TASKS[i]
		var task_id: String = task.get("id", "") as String
		var done: bool = IslandTaskState.is_task_complete(task_id)
		var prefix: String = "[x] " if done else "[ ] "
		var board_text: String = task.get("board_text", "") as String
		labels[i].text = "%s任务%s：%s" % [prefix, _number_label(i + 1), board_text]
		if done:
			labels[i].modulate = Color(0.78, 1.0, 0.8, 1.0)
		else:
			labels[i].modulate = Color(1, 1, 1, 1)

	var done_count: int = IslandTaskState.get_completed_count()
	_hint.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		"进度：%d/5   前往星途岛完成任务    Esc 返回" % done_count,
		"再按 Enter 确认返回主场景"
	)


func _number_label(index: int) -> String:
	match index:
		1: return "一"
		2: return "二"
		3: return "三"
		4: return "四"
		5: return "五"
		_: return str(index)


func _set_esc_confirm_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_refresh_task_labels()


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
