extends Control

signal closed

const FONT_PATH := "res://HYPixel11pxU-2.ttf"
const EXAM_RESOURCE_DIR := "res://考试"
const TODO_STATE_PATH := "user://exam_todo_state.json"

const COLOR_PANEL := Color(0.035, 0.05, 0.1, 0.985)
const COLOR_ACCENT := Color(0.58, 0.76, 1.0, 0.95)
const COLOR_TEXT := Color(0.92, 0.96, 1.0, 1.0)
const COLOR_MUTED := Color(0.65, 0.74, 0.88, 1.0)
const COLOR_EVENT := Color(1.0, 0.75, 0.42, 1.0)
const COLOR_CELL_BG := Color(0.065, 0.095, 0.17, 1.0)
const COLOR_CELL_HEADER := Color(0.13, 0.19, 0.34, 1.0)
const COLOR_CELL_BORDER := Color(0.38, 0.55, 0.82, 0.65)
const COLOR_TABLE_SURFACE := Color(0.045, 0.07, 0.135, 0.97)
const TABLE_ROW_HEIGHT_HEADER := 54
const TABLE_ROW_HEIGHT_DATA := 74
const TABLE_GAP := 10.0
const TABLE_COL_RATIOS := [2.9, 2.25, 1.35, 1.45, 1.55]

## 待办表格：与提供的期末考试表一致（不依赖运行时是否加载日程）
const EXAM_TODO_TABLE: Array[Dictionary] = [
	{
		"id": "exam_academic_lang_2",
		"title": "学术语言与研究方法 II",
		"exam_time": "2026-06-05 15:00-17:00",
		"location": "27-0102",
		"notes": "固定安排",
		"resource_folder": "",
	},
	{
		"id": "exam_info_security",
		"title": "信息安全",
		"exam_time": "2026-06-12",
		"location": "未知",
		"notes": "考试时间不确定",
		"resource_folder": "信息安全",
	},
	{
		"id": "exam_computer_network",
		"title": "计算机网络",
		"exam_time": "2026-06-15 14:30-16:30",
		"location": "27教0101",
		"notes": "固定安排",
		"resource_folder": "计网",
	},
	{
		"id": "exam_probability",
		"title": "概率论与数理统计",
		"exam_time": "2026-06-16 10:00-12:00",
		"location": "27-302",
		"notes": "固定安排",
		"resource_folder": "概率论",
	},
	{
		"id": "exam_discrete_math",
		"title": "离散数学",
		"exam_time": "2026-06-26 09:00-11:00",
		"location": "8教605",
		"notes": "固定安排",
		"resource_folder": "离散、",
	},
	{
		"id": "exam_xjp_thought",
		"title": "习近平新时代中国特色社会主义思想概论",
		"exam_time": "2026-06-27 15:00-17:00",
		"location": "27-0406",
		"notes": "固定安排",
		"resource_folder": "习概",
	},
]

## 考试 id →「考试」目录下子文件夹名（与资源面板一致）
const EXAM_FOLDER_BY_ID := {
	"exam_academic_lang_2": "",
	"exam_info_security": "信息安全",
	"exam_computer_network": "计网",
	"exam_probability": "概率论",
	"exam_discrete_math": "离散、",
	"exam_xjp_thought": "习概",
}

var _font: Font = null
var _mode: String = "todo"
var _title: Label = null
var _content_root: VBoxContainer = null
var _tab_todo_btn: Button = null
var _tab_resources_btn: Button = null

var _todo_done: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(FONT_PATH) as Font
	_load_todo_state()
	_build_ui()
	var schedule := get_node_or_null("/root/ScheduleData")
	if schedule != null and schedule.has_signal("events_changed"):
		schedule.events_changed.connect(_on_schedule_events_changed)


func open_panel(mode: String) -> void:
	_mode = mode if mode in ["todo", "resources"] else "todo"
	_refresh_content()
	visible = true
	call_deferred("_fix_content_layout")


func close_panel() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_schedule_events_changed() -> void:
	if visible and _mode == "todo":
		_refresh_content()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.02, 0.06, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_panel_style(panel, COLOR_PANEL, 0, Color(0, 0, 0, 0), 0)
	add_child(panel)

	var header := HBoxContainer.new()
	header.anchor_left = 0.0
	header.anchor_top = 0.0
	header.anchor_right = 1.0
	header.anchor_bottom = 0.0
	header.offset_left = 48
	header.offset_top = 28
	header.offset_right = -48
	header.offset_bottom = 92
	header.add_theme_constant_override("separation", 18)
	panel.add_child(header)

	_title = _make_label("", 34)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.modulate = COLOR_TEXT
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_title)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	_tab_todo_btn = _make_header_button("待办", func() -> void: open_panel("todo"))
	_tab_resources_btn = _make_header_button("资源", func() -> void: open_panel("resources"))
	btn_row.add_child(_tab_todo_btn)
	btn_row.add_child(_tab_resources_btn)
	btn_row.add_child(_make_header_button("关闭", close_panel))
	header.add_child(btn_row)

	var content_panel := Panel.new()
	content_panel.anchor_left = 0.0
	content_panel.anchor_top = 0.0
	content_panel.anchor_right = 1.0
	content_panel.anchor_bottom = 1.0
	content_panel.offset_left = 48
	content_panel.offset_top = 108
	content_panel.offset_right = -48
	content_panel.offset_bottom = -42
	_apply_panel_style(content_panel, COLOR_TABLE_SURFACE, 18, COLOR_ACCENT, 1)
	panel.add_child(content_panel)

	_content_root = VBoxContainer.new()
	_content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_root.offset_left = 24
	_content_root.offset_top = 22
	_content_root.offset_right = -24
	_content_root.offset_bottom = -22
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 12)
	content_panel.add_child(_content_root)


func _refresh_content() -> void:
	if _content_root == null:
		return
	for child in _content_root.get_children():
		child.queue_free()
	if _mode == "resources":
		_title.text = "考试资源"
		_build_resources_content()
	else:
		_title.text = "期末考试安排"
		_build_todo_content()
	_update_tab_styles()


func _fix_content_layout() -> void:
	if _content_root == null:
		return
	_content_root.queue_sort()
	var parent := _content_root.get_parent()
	if parent is Container:
		(parent as Container).queue_sort()


func _update_tab_styles() -> void:
	_style_tab_button(_tab_todo_btn, _mode == "todo")
	_style_tab_button(_tab_resources_btn, _mode == "resources")


func _style_tab_button(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		btn.add_theme_color_override("font_color", COLOR_EVENT)
	else:
		btn.add_theme_color_override("font_color", COLOR_MUTED)


func _build_todo_content() -> void:
	var table := _build_fullscreen_exam_table()
	_content_root.add_child(table)


func _make_content_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return scroll


func _build_fullscreen_exam_table() -> Control:
	var table := Control.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.custom_minimum_size = Vector2(900, 610)
	table.clip_contents = true
	table.resized.connect(func() -> void: _layout_fullscreen_exam_table(table))

	var headers := ["课程名称", "考试时间", "考试地点", "备注", "操作"]
	for col in range(headers.size()):
		_add_exam_table_cell(table, 0, col, headers[col], true, {}, "")

	for row_index in range(EXAM_TODO_TABLE.size()):
		var row_data: Dictionary = EXAM_TODO_TABLE[row_index]
		var id := str(row_data.get("id", ""))
		_add_exam_table_cell(table, row_index + 1, 0, str(row_data.get("title", "")), false, row_data, "course")
		_add_exam_table_cell(table, row_index + 1, 1, str(row_data.get("exam_time", "")), false, row_data, "time")
		_add_exam_table_cell(table, row_index + 1, 2, str(row_data.get("location", "")), false, row_data, "location")
		_add_exam_table_cell(table, row_index + 1, 3, str(row_data.get("notes", "")), false, row_data, "notes")
		_add_exam_action_cell(table, row_index + 1, 4, id, row_data)

	call_deferred("_layout_fullscreen_exam_table", table)
	return table


func _add_exam_table_cell(
	table: Control,
	row: int,
	col: int,
	text: String,
	is_header: bool,
	row_data: Dictionary,
	cell_kind: String
) -> void:
	var panel := Panel.new()
	panel.set_meta("table_row", row)
	panel.set_meta("table_col", col)
	_apply_panel_style(panel, COLOR_CELL_HEADER if is_header else COLOR_CELL_BG, 12, COLOR_CELL_BORDER, 1)
	table.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var label := _make_readable_label(text, 24 if is_header else 21, is_header)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_header else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if cell_kind == "time":
		label.text = text.replace(" ", "\n")
	if cell_kind == "course":
		label.modulate = COLOR_EVENT
	margin.add_child(label)

	if cell_kind == "course" and not _exam_folder_name(row_data).is_empty():
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_exam_subject_folder(row_data)
		)


func _add_exam_action_cell(table: Control, row: int, col: int, id: String, row_data: Dictionary) -> void:
	var has_folder := not _exam_folder_name(row_data).is_empty()
	var panel := Panel.new()
	panel.set_meta("table_row", row)
	panel.set_meta("table_col", col)
	_apply_panel_style(panel, COLOR_CELL_BG, 12, COLOR_CELL_BORDER, 1)
	table.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var done := CheckBox.new()
	done.text = "完成"
	done.button_pressed = bool(_todo_done.get(id, false))
	done.toggled.connect(_on_todo_toggled.bind(id))
	if _font != null:
		done.add_theme_font_override("font", _font)
	done.add_theme_font_size_override("font_size", 18)
	done.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(done)

	var folder_btn := _make_tool_button("打开资料" if has_folder else "无资料夹", _open_exam_subject_folder.bind(row_data))
	folder_btn.disabled = not has_folder
	folder_btn.custom_minimum_size = Vector2(150, 44)
	folder_btn.add_theme_font_size_override("font_size", 17)
	box.add_child(folder_btn)


func _layout_fullscreen_exam_table(table: Control) -> void:
	if table == null:
		return
	var total_rows := EXAM_TODO_TABLE.size() + 1
	var width := table.size.x
	var height := table.size.y
	if width <= 0.0 or height <= 0.0:
		return

	var gaps_x := TABLE_GAP * float(TABLE_COL_RATIOS.size() - 1)
	var available_w := maxf(1.0, width - gaps_x)
	var ratio_sum := 0.0
	for ratio in TABLE_COL_RATIOS:
		ratio_sum += float(ratio)

	var col_x: Array[float] = []
	var col_w: Array[float] = []
	var x := 0.0
	for ratio in TABLE_COL_RATIOS:
		var w := available_w * float(ratio) / ratio_sum
		col_x.append(x)
		col_w.append(w)
		x += w + TABLE_GAP

	var header_h := minf(72.0, maxf(58.0, height * 0.11))
	var row_gap_total := TABLE_GAP * float(total_rows - 1)
	var data_h := maxf(78.0, (height - header_h - row_gap_total) / float(EXAM_TODO_TABLE.size()))

	for child in table.get_children():
		if not child is Control:
			continue
		var row := int(child.get_meta("table_row", 0))
		var col := int(child.get_meta("table_col", 0))
		if col < 0 or col >= col_w.size():
			continue
		var y := 0.0
		var h := header_h
		if row > 0:
			y = header_h + TABLE_GAP + float(row - 1) * (data_h + TABLE_GAP)
			h = data_h
		var control := child as Control
		control.position = Vector2(col_x[col], y)
		control.size = Vector2(col_w[col], h)


func _table_col_stretch(col: int) -> float:
	match col:
		0:
			return 3.2
		1:
			return 2.45
		2:
			return 1.25
		3:
			return 1.35
		_:
			return 1.45


func _build_exam_schedule_table() -> VBoxContainer:
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 10)

	table.add_child(
		_build_table_row(
			["课程名称", "考试时间", "考试地点", "备注", "资料"],
			true,
			TABLE_ROW_HEIGHT_HEADER
		)
	)

	for row_data in EXAM_TODO_TABLE:
		var id := str(row_data.get("id", ""))
		var has_folder := not _exam_folder_name(row_data).is_empty()
		table.add_child(_build_exam_data_row(id, row_data, has_folder))

	return table


func _build_exam_data_row(id: String, row_data: Dictionary, has_folder: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, TABLE_ROW_HEIGHT_DATA)
	row.add_theme_constant_override("separation", 12)

	var course_cell := _make_table_cell("", false, _table_col_stretch(0))
	_replace_cell_with_course_button(course_cell, row_data, has_folder)
	row.add_child(course_cell)

	row.add_child(_make_table_cell(str(row_data.get("exam_time", "")), false, _table_col_stretch(1)))
	row.add_child(_make_table_cell(str(row_data.get("location", "")), false, _table_col_stretch(2)))
	row.add_child(_make_table_cell(str(row_data.get("notes", "")), false, _table_col_stretch(3)))

	var action_cell := _make_table_action_cell(id, row_data, has_folder)
	action_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_cell.size_flags_stretch_ratio = _table_col_stretch(4)
	row.add_child(action_cell)

	return row


func _build_table_row(texts: Array, is_header: bool, row_height: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, row_height)
	row.add_theme_constant_override("separation", 12)

	for col in range(texts.size()):
		var cell := _make_table_cell(str(texts[col]), is_header, _table_col_stretch(col))
		row.add_child(cell)

	return row


func _make_table_cell(text: String, is_header: bool, stretch: float) -> Panel:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	_apply_panel_style(panel, COLOR_CELL_HEADER if is_header else COLOR_CELL_BG, 10, COLOR_CELL_BORDER, 1)

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inner)

	if not text.is_empty():
		var label := _make_readable_label(text, 17 if is_header else 15, is_header)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		inner.add_child(label)

	return panel


func _replace_cell_with_course_button(cell: Panel, row_data: Dictionary, has_folder: bool) -> void:
	for child in cell.get_children():
		child.queue_free()

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 12)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_bottom", 10)
	cell.add_child(inner)

	var title := str(row_data.get("title", ""))
	if has_folder:
		var course_btn := Button.new()
		course_btn.text = title
		course_btn.focus_mode = Control.FOCUS_NONE
		course_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		course_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _font != null:
			course_btn.add_theme_font_override("font", _font)
		course_btn.add_theme_font_size_override("font_size", 15)
		course_btn.add_theme_color_override("font_color", COLOR_EVENT)
		course_btn.pressed.connect(_open_exam_subject_folder.bind(row_data))
		_apply_button_style(course_btn)
		inner.add_child(course_btn)
	else:
		inner.add_child(_make_readable_label(title, 15, false))


func _make_table_action_cell(id: String, row_data: Dictionary, has_folder: bool) -> Panel:
	var panel := Panel.new()
	_apply_panel_style(panel, COLOR_CELL_BG, 10, COLOR_CELL_BORDER, 1)

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 10)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_right", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(inner)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var done := CheckBox.new()
	done.text = "完成"
	done.button_pressed = bool(_todo_done.get(id, false))
	done.toggled.connect(_on_todo_toggled.bind(id))
	if _font != null:
		done.add_theme_font_override("font", _font)
	done.add_theme_font_size_override("font_size", 14)
	box.add_child(done)

	var folder_btn := _make_tool_button(
		"打开资料" if has_folder else "无资料夹",
		_open_exam_subject_folder.bind(row_data)
	)
	folder_btn.custom_minimum_size = Vector2(132, 42)
	folder_btn.disabled = not has_folder
	if _font != null:
		folder_btn.add_theme_font_size_override("font_size", 14)
	box.add_child(folder_btn)
	inner.add_child(box)

	return panel


func _make_readable_label(text: String, font_size: int, is_header: bool) -> Label:
	var label := _make_label(text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = COLOR_EVENT if is_header else COLOR_TEXT
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _build_resources_content() -> void:
	_content_root.add_child(_make_info_banner(
		"考试资料在「考试」文件夹。点下方按钮打开根目录，或点每个文件的「打开」。",
		_open_exam_resource_folder,
		"打开考试文件夹"
	))

	var files := _scan_resource_files()
	if files.is_empty():
		_content_root.add_child(_make_info_banner("未扫描到文件，请确认项目里有「考试」文件夹。", Callable()))
		return

	var scroll := _make_content_scroll()
	_content_root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var current_group := ""
	for file_info in files:
		var group := str(file_info.get("group", "其他"))
		if group != current_group:
			current_group = group
			var group_panel := Panel.new()
			group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			group_panel.custom_minimum_size = Vector2(0, 44)
			_apply_panel_style(group_panel, COLOR_CELL_HEADER, 8, COLOR_CELL_BORDER, 1)
			var group_margin := MarginContainer.new()
			group_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			group_margin.add_theme_constant_override("margin_left", 12)
			group_margin.add_theme_constant_override("margin_top", 8)
			group_margin.add_theme_constant_override("margin_right", 12)
			group_margin.add_theme_constant_override("margin_bottom", 8)
			group_panel.add_child(group_margin)
			var group_label := _make_readable_label(current_group, 21, true)
			group_margin.add_child(group_label)
			list.add_child(group_panel)
		list.add_child(_make_resource_row(file_info))


func _make_resource_row(file_info: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 58)
	_apply_panel_style(panel, COLOR_CELL_BG, 10, COLOR_CELL_BORDER, 1)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var name_label := _make_readable_label(str(file_info.get("name", "")), 18, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)

	var meta := _make_readable_label(str(file_info.get("meta", "")), 16, false)
	meta.modulate = COLOR_MUTED
	meta.custom_minimum_size = Vector2(88, 0)
	row.add_child(meta)

	var open_btn := _make_tool_button("打开", _open_resource_file.bind(str(file_info.get("path", ""))))
	open_btn.custom_minimum_size = Vector2(96, 38)
	row.add_child(open_btn)

	return panel


func _exam_events() -> Array[Dictionary]:
	var schedule := get_node_or_null("/root/ScheduleData")
	var events: Array[Dictionary] = []
	if schedule != null and schedule.has_method("get_all_events"):
		for event in schedule.get_all_events():
			if str(event.get("category", "")) == "exam":
				events.append(event)
	if events.is_empty():
		events = _load_bundled_exam_events()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _event_sort_key(a) < _event_sort_key(b)
	)
	return events


func _load_bundled_exam_events() -> Array[Dictionary]:
	const BUNDLED_PATH := "res://data/schedule.json"
	if not FileAccess.file_exists(BUNDLED_PATH):
		return [] as Array[Dictionary]
	var file := FileAccess.open(BUNDLED_PATH, FileAccess.READ)
	if file == null:
		return [] as Array[Dictionary]
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return [] as Array[Dictionary]
	var raw: Array = (parsed as Dictionary).get("events", []) as Array
	var result: Array[Dictionary] = []
	for item in raw:
		if item is Dictionary and str((item as Dictionary).get("category", "")) == "exam":
			result.append(item as Dictionary)
	return result


func _event_sort_key(event: Dictionary) -> String:
	return "%s %s" % [str(event.get("date", "")), str(event.get("time_start", "99:99"))]


func _event_exam_datetime_text(event: Dictionary) -> String:
	var date := str(event.get("date", ""))
	var start := str(event.get("time_start", ""))
	var end := str(event.get("time_end", ""))
	if date.is_empty():
		return "未定"
	if start.is_empty() and end.is_empty():
		return date
	if not start.is_empty() and not end.is_empty():
		return "%s %s-%s" % [date, start, end]
	if not start.is_empty():
		return "%s %s" % [date, start]
	return "%s %s" % [date, end]


func _exam_folder_name(event: Dictionary) -> String:
	var folder := str(event.get("resource_folder", "")).strip_edges()
	if not folder.is_empty():
		return folder
	var id := str(event.get("id", ""))
	if EXAM_FOLDER_BY_ID.has(id):
		folder = str(EXAM_FOLDER_BY_ID[id]).strip_edges()
		if not folder.is_empty():
			return folder
	return _discover_exam_folder(str(event.get("title", "")))


func _discover_exam_folder(title: String) -> String:
	if title.is_empty():
		return ""
	var abs_root := ProjectSettings.globalize_path(EXAM_RESOURCE_DIR)
	var dir := DirAccess.open(abs_root)
	if dir == null:
		return ""
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with(".") or not dir.current_is_dir():
			continue
		if title == _friendly_group_label(name) or title.contains(name):
			dir.list_dir_end()
			return name
	dir.list_dir_end()
	return ""


func _open_exam_subject_folder(event: Dictionary) -> void:
	var folder_name := _exam_folder_name(event)
	if folder_name.is_empty():
		_open_exam_resource_folder()
		return
	var rel_path := "%s/%s" % [EXAM_RESOURCE_DIR, folder_name]
	var abs_path := ProjectSettings.globalize_path(rel_path)
	if not DirAccess.dir_exists_absolute(abs_path):
		push_warning("考试资料夹不存在: %s" % abs_path)
		_open_exam_resource_folder()
		return
	OS.shell_open(abs_path)


func _scan_resource_files() -> Array[Dictionary]:
	var root := ProjectSettings.globalize_path(EXAM_RESOURCE_DIR)
	var result: Array[Dictionary] = []
	_scan_dir_recursive(root, "", result, 0)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ag := str(a.get("group", ""))
		var bg := str(b.get("group", ""))
		if ag == bg:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return ag < bg
	)
	return result


func _scan_dir_recursive(abs_dir: String, rel_dir: String, output: Array[Dictionary], depth: int) -> void:
	if depth > 4:
		return
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var abs_path := abs_dir.path_join(name)
		var rel_path := rel_dir.path_join(name) if not rel_dir.is_empty() else name
		if dir.current_is_dir():
			_scan_dir_recursive(abs_path, rel_path, output, depth + 1)
			continue
		output.append({
			"name": _friendly_file_label(rel_path),
			"group": _friendly_group_label(rel_path),
			"path": abs_path,
			"meta": _file_meta(abs_path),
		})
	dir.list_dir_end()


func _friendly_group_label(rel_path: String) -> String:
	var top := rel_path.split("/")[0].split("\\")[0]
	var labels := {
		"习概": "习近平新时代中国特色社会主义思想概论",
		"信息安全": "信息安全",
		"概率论": "概率论与数理统计",
		"离散、": "离散数学",
		"计网": "计算机网络",
	}
	return str(labels.get(top, top))


func _friendly_file_label(rel_path: String) -> String:
	return rel_path.replace("\\", " / ")


func _file_meta(abs_path: String) -> String:
	if not FileAccess.file_exists(abs_path):
		return ""
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_length()
	file.close()
	if bytes >= 1024 * 1024:
		return "%.1f MB" % (float(bytes) / 1024.0 / 1024.0)
	if bytes >= 1024:
		return "%d KB" % int(bytes / 1024)
	return "%d B" % bytes


func _open_exam_resource_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(EXAM_RESOURCE_DIR))


func _open_resource_file(path: String) -> void:
	if path.is_empty():
		return
	OS.shell_open(path)


func _on_todo_toggled(done: bool, id: String) -> void:
	_todo_done[id] = done
	_save_todo_state()


func _load_todo_state() -> void:
	if not FileAccess.file_exists(TODO_STATE_PATH):
		return
	var file := FileAccess.open(TODO_STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_todo_done = parsed as Dictionary


func _save_todo_state() -> void:
	var file := FileAccess.open(TODO_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_todo_done))
	file.close()


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_info_banner(message: String, callback: Callable, button_text: String = "") -> Panel:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 58)
	_apply_panel_style(panel, COLOR_CELL_HEADER, 10, COLOR_CELL_BORDER, 1)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	margin.add_child(row)

	var label := _make_readable_label(message, 18, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	if not button_text.is_empty() and callback.is_valid():
		var btn := _make_tool_button(button_text, callback)
		btn.custom_minimum_size = Vector2(140, 40)
		if _font != null:
			btn.add_theme_font_size_override("font_size", 15)
		row.add_child(btn)

	return panel


func _make_header_button(text: String, callback: Callable) -> Button:
	var btn := _make_tool_button(text, callback)
	btn.custom_minimum_size = Vector2(124, 54)
	if _font != null:
		btn.add_theme_font_size_override("font_size", 20)
	return btn


func _make_tool_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	if _font != null:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.7, 1))
	btn.pressed.connect(callback)
	_apply_button_style(btn)
	return btn


func _apply_panel_style(
	panel: Panel,
	bg: Color,
	radius: int,
	border: Color,
	border_width: int
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.set_border_width_all(border_width)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)


func _apply_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.29, 0.52, 1.0)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.border_color = Color(0.5, 0.68, 1.0, 0.65)
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.38, 0.66, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)