extends "res://world_page.gd"

const IslandTaskData = preload("res://island_task_data.gd")
const IslandTaskState = preload("res://island_task_state.gd")
const CodexState = preload("res://codex_state.gd")

const WATER_GRID_SIZE := Vector2i(24, 24)
const WATER_CELL_THRESHOLD := 0.55
const WATER_SAMPLE_STEP := 4

const POST_INTRO_LINES: Array[String] = [
	"被抛入这片死寂孤岛，活下去，成了唯一的执念。",
	"好像........活得还挺好，鸡腿好吃QAQ",
]
const POST_INTRO_LINE_DURATION := 4.0

var _post_intro_active: bool = false
var _post_intro_index: int = 0
var _post_intro_elapsed: float = 0.0

var _task_items: Array[Dictionary] = []
var _input_open: bool = false
var _message_open: bool = false
var _ending_open: bool = false
var _active_task: Dictionary = {}
var _zone_hint_task_id: String = ""
var _pending_ending_after_message: bool = false
var _pending_messages: Array[String] = []
@export var codex_scene_path: String = "res://codex.tscn"

const GRANDPA_TREASURE_LINE: String = "祖父的声音仿佛穿过海风：暮秋，你终于找到了。别害怕远方，带着这份勇气继续前行吧。"

@onready var _intro_dialogue_panel: Panel = $UI/IntroDialoguePanel
@onready var _intro_dialogue_label: Label = $UI/IntroDialoguePanel/IntroDialogueLabel
@onready var _task_input_view: Control = $UI/TaskInputView
@onready var _task_prompt: Label = $UI/TaskInputView/InputPanel/PromptLabel
@onready var _task_line_edit: LineEdit = $UI/TaskInputView/InputPanel/AnswerLineEdit
@onready var _task_feedback: Label = $UI/TaskInputView/InputPanel/FeedbackLabel
@onready var _task_input_hint: Label = $UI/TaskInputView/InputHint
@onready var _task_message_view: Control = $UI/TaskMessageView
@onready var _task_message_label: Label = $UI/TaskMessageView/MessagePanel/MessageLabel
@onready var _task_message_hint: Label = $UI/TaskMessageView/MessageHint
@onready var _ending_view: Control = $UI/EndingView
@onready var _ending_label: Label = $UI/EndingView/EndingPanel/EndingLabel
@onready var _ending_hint: Label = $UI/EndingView/EndingHint
@onready var _codex_entry: TextureRect = $UI/CodexEntry


func _ready() -> void:
	_setup_intro_dialogue()
	super._ready()
	_build_water_blockers()
	_build_task_triggers()
	_setup_task_ui()
	_restore_world_progress()
	_update_zone_hint()


func is_intro_video_playing() -> bool:
	return super.is_intro_video_playing() or _post_intro_active


func _process(delta: float) -> void:
	super._process(delta)
	if not _post_intro_active:
		return

	_post_intro_elapsed += delta
	if _post_intro_elapsed < POST_INTRO_LINE_DURATION:
		return

	_post_intro_index += 1
	if _post_intro_index >= POST_INTRO_LINES.size():
		_finish_post_intro_dialogue()
		return

	_post_intro_elapsed = 0.0
	_intro_dialogue_label.text = POST_INTRO_LINES[_post_intro_index]


func _physics_process(_delta: float) -> void:
	if _player == null or _input_open or _message_open or _ending_open:
		return
	if is_intro_video_playing():
		return

	var nearest_hint: String = ""
	for item in _task_items:
		var in_zone: bool = _is_player_in_zone(item)
		item["was_in_zone"] = in_zone
		if in_zone and _can_show_zone_hint(item):
			nearest_hint = item.get("zone_hint", "") as String

	if nearest_hint != _zone_hint_task_id:
		_zone_hint_task_id = nearest_hint
		_update_zone_hint()


func _input(event: InputEvent) -> void:
	if _ending_open:
		if EscExitHelper.is_enter_pressed(event) or event.is_action_pressed("ui_cancel"):
			_close_ending()
			_mark_input_handled()
		return

	if _message_open:
		if EscExitHelper.is_enter_pressed(event) or event.is_action_pressed("ui_cancel"):
			_close_message()
			_mark_input_handled()
		return

	if _input_open:
		_handle_input_dialog(event)
		return

	if is_intro_video_playing():
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if _is_click_on_codex_entry(mouse_event.position):
			_save_world_progress_before_exit()
			get_tree().set_meta("codex_return_scene_path", "res://world_island.tscn")
			get_tree().set_meta("codex_quick_return", true)
			get_tree().change_scene_to_file(codex_scene_path)
			_mark_input_handled()
			return
		for item in _task_items:
			if item.get("was_in_zone", false):
				_on_task_zone_clicked(item)
				_mark_input_handled()
				return


func _unhandled_input(event: InputEvent) -> void:
	if _input_open or _message_open or _ending_open or is_intro_video_playing():
		return
	super._unhandled_input(event)


func _on_intro_sequence_complete() -> void:
	_begin_post_intro_dialogue()


func _begin_post_intro_dialogue() -> void:
	_post_intro_active = true
	_post_intro_index = 0
	_post_intro_elapsed = 0.0
	_intro_dialogue_panel.visible = true
	_intro_dialogue_label.text = POST_INTRO_LINES[0]


func _finish_post_intro_dialogue() -> void:
	_post_intro_active = false
	_intro_dialogue_panel.visible = false
	super._release_player_after_intro()


func _setup_intro_dialogue() -> void:
	_intro_dialogue_panel.visible = false
	var font: FontFile = load(IslandTaskData.FONT_PATH) as FontFile
	if font != null:
		_intro_dialogue_label.add_theme_font_override("font", font)
	_intro_dialogue_label.add_theme_font_size_override("font_size", 22)
	_intro_dialogue_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.9)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 8
	_intro_dialogue_panel.add_theme_stylebox_override("panel", panel_style)


func _build_task_triggers() -> void:
	_task_items.clear()
	for task_config in IslandTaskData.TASKS:
		var item: Dictionary = task_config.duplicate(true) as Dictionary
		var trigger: Area2D = get_node_or_null(item["trigger_path"]) as Area2D
		if trigger == null:
			push_warning("Island task trigger missing: %s" % item["trigger_path"])
			continue
		var shape: CollisionShape2D = trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null:
			continue
		item["trigger"] = trigger
		item["shape"] = shape
		item["was_in_zone"] = false
		trigger.monitoring = true
		trigger.monitorable = false
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		_task_items.append(item)


func _setup_task_ui() -> void:
	var font: FontFile = load(IslandTaskData.FONT_PATH) as FontFile
	if font == null:
		return

	var labels: Array[Label] = [
		_task_prompt,
		_task_feedback,
		_task_input_hint,
		_task_message_label,
		_task_message_hint,
		_ending_label,
		_ending_hint,
		_hint,
	]
	for label: Label in labels:
		label.add_theme_font_override("font", font)

	_task_line_edit.add_theme_font_override("font", font)
	_apply_panel_style($UI/TaskInputView/InputPanel)
	_apply_panel_style($UI/TaskMessageView/MessagePanel)
	_apply_panel_style($UI/EndingView/EndingPanel)

	_task_input_view.visible = false
	_task_message_view.visible = false
	_ending_view.visible = false
	_task_feedback.text = ""
	_task_input_hint.text = "Enter 提交    Esc 关闭"
	_task_message_hint.text = "Enter / Esc 关闭"
	_ending_hint.text = "Enter / Esc 关闭"


func _apply_panel_style(panel: Panel) -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.92)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 16
	panel_style.content_margin_bottom = 12
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.62, 0.52, 0.36, 1)
	panel.add_theme_stylebox_override("panel", panel_style)


func _is_player_in_zone(item: Dictionary) -> bool:
	var shape: CollisionShape2D = item["shape"] as CollisionShape2D
	if shape.shape is not RectangleShape2D:
		return false
	var rect_shape: RectangleShape2D = shape.shape as RectangleShape2D
	var shape_scale: Vector2 = shape.global_transform.get_scale()
	var size: Vector2 = Vector2(
		rect_shape.size.x * absf(shape_scale.x),
		rect_shape.size.y * absf(shape_scale.y)
	)
	var center: Vector2 = shape.global_position
	var zone_rect: Rect2 = Rect2(center - size * 0.5, size)
	var player_half: Vector2 = _player.get_collision_half_extents()
	var player_rect: Rect2 = Rect2(_player.global_position - player_half, player_half * 2.0)
	return zone_rect.intersects(player_rect)


func _can_show_zone_hint(item: Dictionary) -> bool:
	var task_id: String = item.get("id", "") as String
	if task_id == "treasure" and not IslandTaskState.core_tasks_complete():
		return false
	return true


func _on_task_zone_clicked(item: Dictionary) -> void:
	var task_id: String = item.get("id", "") as String
	if IslandTaskState.is_task_complete(task_id):
		_show_message("该任务已完成。")
		return

	if not _requirements_met(item):
		_show_message(item.get("fail_text", "条件尚未满足。") as String)
		return

	if bool(item.get("no_input", false)):
		_complete_task(item)
		return

	_open_input_dialog(item)


func _requirements_met(item: Dictionary) -> bool:
	var required: Array = item.get("requires_prior", [])
	for prior_id in required:
		if not IslandTaskState.is_task_complete(str(prior_id)):
			return false
	return true


func _open_input_dialog(item: Dictionary) -> void:
	_active_task = item
	_input_open = true
	_task_prompt.text = item.get("prompt", "") as String
	_task_feedback.text = ""
	_task_line_edit.text = ""
	_task_line_edit.grab_focus()
	_task_input_view.visible = true
	_hint.visible = false
	_release_player_control()


func _handle_input_dialog(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_input_dialog()
		_mark_input_handled()
		return

	if EscExitHelper.is_enter_pressed(event):
		_submit_input_answer()
		_mark_input_handled()


func _submit_input_answer() -> void:
	if _active_task.is_empty():
		return

	var answer: String = str(_active_task.get("answer", ""))
	var user_text: String = _task_line_edit.text.strip_edges()
	if user_text == answer:
		_complete_task(_active_task)
	else:
		_task_feedback.text = _active_task.get("fail_text", "答案不对。") as String


func _complete_task(item: Dictionary) -> void:
	var task_id: String = item.get("id", "") as String
	IslandTaskState.complete_task(task_id)
	if task_id == "treasure":
		CodexState.unlock_treasure()
		_pending_messages.append(GRANDPA_TREASURE_LINE)
	_close_input_dialog()
	if IslandTaskState.all_complete() and not IslandTaskState.is_ending_seen():
		_pending_ending_after_message = true
	_show_message(item.get("success_text", "该任务已完成。") as String)


func _close_input_dialog() -> void:
	_input_open = false
	_active_task = {}
	_task_input_view.visible = false
	_hint.visible = true
	_release_player_control()


func _show_message(text: String) -> void:
	_message_open = true
	_task_message_label.text = text
	_task_message_view.visible = true
	_hint.visible = false
	_release_player_control()


func _close_message() -> void:
	_message_open = false
	_task_message_view.visible = false
	_hint.visible = true
	_update_zone_hint()
	_release_player_control()
	if not _pending_messages.is_empty():
		var next_message: String = _pending_messages[0]
		_pending_messages.remove_at(0)
		_show_message(next_message)
		return
	if _pending_ending_after_message:
		_pending_ending_after_message = false
		_show_ending()


func _show_ending() -> void:
	_ending_open = true
	_ending_label.text = IslandTaskData.ENDING_TEXT
	_ending_view.visible = true
	_hint.visible = false
	IslandTaskState.mark_ending_seen()
	_release_player_control()


func _close_ending() -> void:
	_ending_open = false
	_ending_view.visible = false
	_hint.visible = true
	_update_zone_hint()
	_release_player_control()


func _update_zone_hint() -> void:
	if _input_open or _message_open or _ending_open:
		return

	var base_hint: String = EscExitHelper.hint_text(
		_esc_confirm_pending,
		"Esc 返回世界选择",
		"再按 Enter 确认返回世界选择"
	)
	if _zone_hint_task_id.is_empty():
		_hint.text = base_hint
		return

	_hint.text = "%s    |    点击 %s 交互" % [base_hint, _zone_hint_task_id]


func _set_esc_confirm_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_update_zone_hint()


func _release_player_control() -> void:
	if _player == null:
		return
	var locked: bool = (
		_input_open
		or _message_open
		or _ending_open
		or is_intro_video_playing()
	)
	_player.set_physics_process(not locked)


func _is_click_on_codex_entry(screen_pos: Vector2) -> bool:
	if _codex_entry == null or not _codex_entry.visible:
		return false
	if codex_scene_path.is_empty():
		return false
	return _codex_entry.get_global_rect().has_point(screen_pos)


func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _build_water_blockers() -> void:
	var sprite: Sprite2D = _background as Sprite2D
	if sprite == null or sprite.texture == null:
		return

	var image: Image = sprite.texture.get_image()
	if image.is_empty():
		return

	var existing: Node = sprite.get_node_or_null("WaterBlockers")
	if existing != null:
		existing.queue_free()

	var blockers: Node2D = Node2D.new()
	blockers.name = "WaterBlockers"
	sprite.add_child(blockers)

	var tex_size: Vector2 = image.get_size()
	var tex_w: int = int(tex_size.x)
	var tex_h: int = int(tex_size.y)
	var grid_w: int = WATER_GRID_SIZE.x
	var grid_h: int = WATER_GRID_SIZE.y
	var grid: Array = []

	for gy in range(grid_h):
		var row: Array[bool] = []
		for gx in range(grid_w):
			row.append(_cell_is_water(image, gx, gy, grid_w, grid_h, tex_w, tex_h))
		grid.append(row)

	for gy in range(grid_h):
		var gx: int = 0
		while gx < grid_w:
			if not grid[gy][gx]:
				gx += 1
				continue

			var start_gx: int = gx
			while gx < grid_w and grid[gy][gx]:
				gx += 1

			var x0: int = int(float(start_gx * tex_w) / float(grid_w))
			var x1: int = int(float(gx * tex_w) / float(grid_w))
			var y0: int = int(float(gy * tex_h) / float(grid_h))
			var y1: int = int(float((gy + 1) * tex_h) / float(grid_h))
			_add_water_rect(blockers, x0, y0, x1 - x0, y1 - y0, tex_w, tex_h)


func _cell_is_water(
	image: Image,
	gx: int,
	gy: int,
	grid_w: int,
	grid_h: int,
	tex_w: int,
	tex_h: int
) -> bool:
	var x0: int = int(float(gx * tex_w) / float(grid_w))
	var x1: int = int(float((gx + 1) * tex_w) / float(grid_w))
	var y0: int = int(float(gy * tex_h) / float(grid_h))
	var y1: int = int(float((gy + 1) * tex_h) / float(grid_h))
	var water_count: int = 0
	var total: int = 0

	for y in range(y0, y1, WATER_SAMPLE_STEP):
		for x in range(x0, x1, WATER_SAMPLE_STEP):
			total += 1
			if _is_water_pixel(image.get_pixel(x, y)):
				water_count += 1

	if total == 0:
		return false
	return float(water_count) / float(total) > WATER_CELL_THRESHOLD


func _is_water_pixel(color: Color) -> bool:
	var hue: float = color.h
	var sat: float = color.s
	var val: float = color.v
	var deep_water: bool = (
		hue > 0.45
		and hue < 0.62
		and sat > 0.25
		and val > 0.35
		and val < 0.55
		and color.b > color.r
	)
	var shallow_water: bool = (
		hue > 0.45
		and hue < 0.62
		and sat > 0.15
		and val >= 0.55
		and val < 0.75
		and color.b > color.r + 0.05
	)
	return deep_water or shallow_water


func _add_water_rect(
	parent: Node2D,
	x0: float,
	y0: float,
	width: float,
	height: float,
	tex_w: int,
	tex_h: int
) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(width, height)
	shape_node.shape = rect_shape
	body.position = Vector2(
		x0 + width * 0.5 - tex_w * 0.5,
		y0 + height * 0.5 - tex_h * 0.5
	)
	body.add_child(shape_node)
	parent.add_child(body)
