extends Control

signal closed

const ScheduleDataService = preload("res://schedule_data.gd")
const FONT_PATH := "res://HYPixel11pxU-2.ttf"
const WEEKDAY_HEADERS: PackedStringArray = ["日", "一", "二", "三", "四", "五", "六"]
const WEEKDAY_NAMES: PackedStringArray = ["日", "一", "二", "三", "四", "五", "六"]

var _view_year: int = 2026
var _view_month: int = 6
var _selected_year: int = 2026
var _selected_month: int = 6
var _selected_day: int = 1

var _font: Font
var _month_title: Label
var _today_hint: Label
var _detail_title: Label
var _detail_list: VBoxContainer
var _day_buttons: Array[Button] = []
var _sync_status: Label
var _root_panel: Panel

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load(FONT_PATH) as Font
	_init_view_from_system()
	_build_ui()
	ScheduleData.events_changed.connect(_refresh_all)
	ContentSync.sync_finished.connect(_on_sync_finished)
	_refresh_all()


func open_calendar() -> void:
	_init_view_from_system()
	visible = true
	_refresh_all()


func close_calendar() -> void:
	visible = false
	closed.emit()


func _init_view_from_system() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_view_year = int(now.get("year", 2026))
	_view_month = int(now.get("month", 1))
	_selected_year = _view_year
	_selected_month = _view_month
	_selected_day = int(now.get("day", 1))


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.02, 0.03, 0.08, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_root_panel = Panel.new()
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.offset_left = -520.0
	_root_panel.offset_top = -300.0
	_root_panel.offset_right = 520.0
	_root_panel.offset_bottom = 300.0
	_apply_panel_style(_root_panel, Color(0.07, 0.09, 0.18, 0.96), 18)
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_root_panel.add_child(margin)

	var main_h := HBoxContainer.new()
	main_h.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_h.add_theme_constant_override("separation", 18)
	margin.add_child(main_h)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	main_h.add_child(left)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	left.add_child(header)

	var prev_btn := _make_button("◀", _on_prev_month)
	header.add_child(prev_btn)

	_month_title = _make_label("", 26)
	_month_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_month_title)

	var next_btn := _make_button("▶", _on_next_month)
	header.add_child(next_btn)

	var today_btn := _make_button("今天", _on_jump_today)
	header.add_child(today_btn)

	var sync_btn := _make_button("同步", _on_sync_pressed)
	header.add_child(sync_btn)

	_today_hint = _make_label("", 16)
	_today_hint.modulate = Color(0.72, 0.86, 1.0)
	left.add_child(_today_hint)

	var weekday_row := GridContainer.new()
	weekday_row.columns = 7
	weekday_row.add_theme_constant_override("h_separation", 6)
	weekday_row.add_theme_constant_override("v_separation", 6)
	left.add_child(weekday_row)

	for name in WEEKDAY_HEADERS:
		var wd := _make_label(name, 14)
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weekday_row.add_child(wd)

	var day_grid := GridContainer.new()
	day_grid.columns = 7
	day_grid.add_theme_constant_override("h_separation", 6)
	day_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(day_grid)

	for i in range(42):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_day_pressed.bind(i))
		_apply_day_button_style(btn)
		day_grid.add_child(btn)
		_day_buttons.append(btn)

	var right_panel := Panel.new()
	right_panel.custom_minimum_size = Vector2(300, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_panel_style(right_panel, Color(0.09, 0.12, 0.22, 0.9), 12)
	main_h.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_margin.add_theme_constant_override("margin_left", 14)
	right_margin.add_theme_constant_override("margin_top", 12)
	right_margin.add_theme_constant_override("margin_right", 14)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_panel.add_child(right_margin)

	var right_v := VBoxContainer.new()
	right_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_v.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_v)

	_detail_title = _make_label("当日日程", 20)
	right_v.add_child(_detail_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_v.add_child(scroll)

	_detail_list = VBoxContainer.new()
	_detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail_list)

	_sync_status = _make_label("Tab / Esc 关闭  ·  未配置远程地址时不联网", 13)
	_sync_status.modulate = Color(0.65, 0.72, 0.85)
	right_v.add_child(_sync_status)

	var close_btn := _make_button("关闭 (Esc)", close_calendar)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_v.add_child(close_btn)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		close_calendar()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_TAB:
				close_calendar()
				get_viewport().set_input_as_handled()


func _refresh_all() -> void:
	_refresh_header()
	_refresh_day_grid()
	_refresh_detail_panel()
	_update_sync_hint()


func _refresh_header() -> void:
	_month_title.text = "%04d 年 %02d 月" % [_view_year, _view_month]
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var ty: int = int(now.get("year", 0))
	var tm: int = int(now.get("month", 0))
	var td: int = int(now.get("day", 0))
	var tw: int = clampi(int(now.get("weekday", 0)), 0, 6)
	_today_hint.text = "今天：%04d.%02d.%02d  星期%s" % [ty, tm, td, WEEKDAY_NAMES[tw]]


func _refresh_day_grid() -> void:
	var first_weekday: int = _weekday_of(_view_year, _view_month, 1)
	var days_in_month: int = _days_in_month(_view_year, _view_month)
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var today_y: int = int(now.get("year", 0))
	var today_m: int = int(now.get("month", 0))
	var today_d: int = int(now.get("day", 0))

	for i in range(_day_buttons.size()):
		var btn := _day_buttons[i]
		var day_num: int = i - first_weekday + 1
		if day_num < 1 or day_num > days_in_month:
			btn.text = ""
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.25)
			continue

		btn.disabled = false
		btn.text = str(day_num)
		var has_event := ScheduleData.has_events_on_date(_view_year, _view_month, day_num)
		var is_today := _view_year == today_y and _view_month == today_m and day_num == today_d
		var is_selected := (
			_view_year == _selected_year
			and _view_month == _selected_month
			and day_num == _selected_day
		)

		if is_today and is_selected:
			btn.modulate = Color(0.55, 1.0, 1.0)
		elif is_today:
			btn.modulate = Color(0.45, 0.92, 1.0)
		elif is_selected:
			btn.modulate = Color(0.95, 0.82, 1.0)
		elif has_event:
			btn.modulate = Color(1.0, 0.78, 0.55)
		else:
			btn.modulate = Color(0.88, 0.9, 1.0)


func _refresh_detail_panel() -> void:
	for child in _detail_list.get_children():
		child.queue_free()

	_detail_title.text = "%04d.%02d.%02d  星期%s" % [
		_selected_year,
		_selected_month,
		_selected_day,
		WEEKDAY_NAMES[_weekday_of(_selected_year, _selected_month, _selected_day)]
	]

	var events: Array[Dictionary] = ScheduleData.get_events_on_date(
		_selected_year, _selected_month, _selected_day
	)
	if events.is_empty():
		var empty := _make_label("本日暂无日程", 16)
		empty.modulate = Color(0.7, 0.75, 0.85)
		_detail_list.add_child(empty)
		return

	for event in events:
		_detail_list.add_child(_build_event_card(event))


func _build_event_card(event: Dictionary) -> Panel:
	var card := Panel.new()
	_apply_panel_style(card, Color(0.12, 0.15, 0.28, 0.95), 10)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("margin_left", 10)
	box.add_theme_constant_override("margin_top", 8)
	box.add_theme_constant_override("margin_right", 10)
	box.add_theme_constant_override("margin_bottom", 8)
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var category: String = str(event.get("category", "event"))
	var tag := "考试" if category == "exam" else "活动"
	var title := _make_label("[%s] %s" % [tag, event.get("title", "未命名")], 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	var time_start: String = str(event.get("time_start", ""))
	var time_end: String = str(event.get("time_end", ""))
	var time_text: String = "时间待定"
	if not time_start.is_empty() and not time_end.is_empty():
		time_text = "%s – %s" % [time_start, time_end]
	elif not time_start.is_empty():
		time_text = time_start

	box.add_child(_make_label("🕒 %s" % time_text, 14))

	var location: String = str(event.get("location", ""))
	if not location.is_empty():
		box.add_child(_make_label("📍 %s" % location, 14))

	var notes: String = str(event.get("notes", ""))
	if not notes.is_empty():
		var note_label := _make_label("· %s" % notes, 13)
		note_label.modulate = Color(0.75, 0.82, 0.95)
		box.add_child(note_label)

	return card


func _on_day_pressed(cell_index: int) -> void:
	var first_weekday: int = _weekday_of(_view_year, _view_month, 1)
	var day_num: int = cell_index - first_weekday + 1
	if day_num < 1 or day_num > _days_in_month(_view_year, _view_month):
		return
	_selected_year = _view_year
	_selected_month = _view_month
	_selected_day = day_num
	_refresh_day_grid()
	_refresh_detail_panel()


func _on_prev_month() -> void:
	_view_month -= 1
	if _view_month < 1:
		_view_month = 12
		_view_year -= 1
	_refresh_all()


func _on_next_month() -> void:
	_view_month += 1
	if _view_month > 12:
		_view_month = 1
		_view_year += 1
	_refresh_all()


func _on_jump_today() -> void:
	_init_view_from_system()
	_refresh_all()


func _on_sync_pressed() -> void:
	if ContentSync.get_manifest_url().is_empty():
		_sync_status.text = "请先在 user://content_sync.cfg 配置 manifest_url"
		return
	_sync_status.text = "正在同步..."
	ContentSync.sync_now()


func _on_sync_finished(success: bool, message: String) -> void:
	_sync_status.text = message if success else ("同步失败: " + message)
	if success:
		_refresh_all()


func _update_sync_hint() -> void:
	if ContentSync.get_manifest_url().is_empty():
		return
	_sync_status.text = "已配置远程 manifest，可点「同步」拉取最新日程"


func _weekday_of(year: int, month: int, day: int) -> int:
	# 0=Sunday
	var t := Time.get_unix_time_from_datetime_dict({
		"year": year,
		"month": month,
		"day": day,
		"hour": 12,
		"minute": 0,
		"second": 0,
	})
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(t)
	return clampi(int(dt.get("weekday", 0)), 0, 6)


func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
		return 29 if leap else 28
	if month in [4, 6, 9, 11]:
		return 30
	return 31


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	if _font != null:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(callback)
	_apply_day_button_style(btn)
	return btn


func _apply_panel_style(panel: Panel, bg: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.48, 0.75, 0.55)
	panel.add_theme_stylebox_override("panel", style)


func _apply_day_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.14, 0.24, 0.9)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.22, 0.36, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
