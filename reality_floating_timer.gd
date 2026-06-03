extends Control

signal timer_visibility_changed(is_visible: bool)

const FONT_PATH := "res://HYPixel11pxU-2.ttf"
const STATE_PATH := "user://reality_timer_state.json"
const PANEL_SIZE := Vector2(300, 330)
const DEFAULT_MARGIN := Vector2(24, 24)

var _font: Font = null
var _panel: Panel = null
var _timer_label: Label = null
var _timer_status: Label = null
var _timer_title_edit: LineEdit = null
var _hour_spin: SpinBox = null
var _minute_spin: SpinBox = null
var _second_spin: SpinBox = null
var _timer_dialog: AcceptDialog = null

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO
var _timer_remaining := 0.0
var _timer_running := false
var _timer_title := "倒计时提醒"
var _panel_visible := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(FONT_PATH) as Font
	_build_ui()
	_load_state()
	_clamp_panel_position()
	set_process(false)


func toggle_visibility() -> void:
	_panel_visible = not _panel_visible
	if _panel != null:
		_panel.visible = _panel_visible
	_save_state()
	timer_visibility_changed.emit(_panel_visible)


func place_bottom_left() -> void:
	if _panel == null:
		return
	_panel.position = _default_position()
	_clamp_panel_position()
	_panel_visible = true
	_panel.visible = true
	_save_state()
	timer_visibility_changed.emit(true)


func is_visible_timer() -> bool:
	return _panel_visible and _panel != null and _panel.visible


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_apply_panel_style(_panel, Color(0.08, 0.1, 0.2, 0.95), 16, Color(1.0, 0.68, 0.32, 1.0))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)

	var drag_handle := Label.new()
	drag_handle.text = "⋮⋮ 拖动计时器"
	drag_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	if _font != null:
		drag_handle.add_theme_font_override("font", _font)
	drag_handle.add_theme_font_size_override("font_size", 14)
	drag_handle.modulate = Color(1.0, 0.86, 0.55, 1.0)
	drag_handle.gui_input.connect(_on_drag_handle_input)
	header.add_child(drag_handle)

	header.add_child(_make_tool_button("放置", place_bottom_left))
	header.add_child(_make_tool_button("隐藏", toggle_visibility))

	var title := _make_label("专注计时器", 20)
	title.modulate = Color(1.0, 0.86, 0.55, 1.0)
	box.add_child(title)

	_timer_label = _make_label("00:00:00", 34)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_label)

	_timer_title_edit = LineEdit.new()
	_timer_title_edit.placeholder_text = "提醒内容，例如：背概率论"
	_timer_title_edit.text = _timer_title
	if _font != null:
		_timer_title_edit.add_theme_font_override("font", _font)
	_timer_title_edit.add_theme_font_size_override("font_size", 14)
	box.add_child(_timer_title_edit)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	box.add_child(time_row)
	_hour_spin = _make_spin(0, 12, 0, "时")
	_minute_spin = _make_spin(0, 59, 25, "分")
	_second_spin = _make_spin(0, 59, 0, "秒")
	time_row.add_child(_hour_spin)
	time_row.add_child(_minute_spin)
	time_row.add_child(_second_spin)

	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 6)
	box.add_child(quick_row)
	for minutes in [5, 15, 25, 45]:
		quick_row.add_child(_make_tool_button("%d 分" % minutes, _set_quick_timer.bind(minutes)))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	box.add_child(action_row)
	action_row.add_child(_make_tool_button("开始", _start_timer))
	action_row.add_child(_make_tool_button("暂停", _pause_timer))
	action_row.add_child(_make_tool_button("重置", _reset_timer))

	_timer_status = _make_label("可拖到任意位置，到点会弹窗提醒。", 12)
	_timer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timer_status.modulate = Color(0.62, 0.7, 0.85, 1.0)
	box.add_child(_timer_status)

	_timer_dialog = AcceptDialog.new()
	_timer_dialog.title = "时间到了"
	add_child(_timer_dialog)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_clamp_panel_position()


func _process(delta: float) -> void:
	if not _timer_running:
		return
	_timer_remaining = maxf(0.0, _timer_remaining - delta)
	_refresh_timer_label()
	if _timer_remaining <= 0.0:
		_timer_running = false
		set_process(false)
		_show_timer_alert()


func _on_drag_handle_input(event: InputEvent) -> void:
	if _panel == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_dragging = true
			_drag_start_mouse = mouse_event.global_position
			_drag_start_pos = _panel.position
		else:
			_dragging = false
			_save_state()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_panel.position = _drag_start_pos + (motion.global_position - _drag_start_mouse)
		_clamp_panel_position()


func _default_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		DEFAULT_MARGIN.x,
		viewport_size.y - PANEL_SIZE.y - DEFAULT_MARGIN.y
	)


func _clamp_panel_position() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	_panel.position.x = clampf(_panel.position.x, 0.0, maxf(0.0, viewport_size.x - PANEL_SIZE.x))
	_panel.position.y = clampf(_panel.position.y, 0.0, maxf(0.0, viewport_size.y - PANEL_SIZE.y))


func _load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		_panel.position = _default_position()
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		_panel.position = _default_position()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var data := parsed as Dictionary
		_panel.position = Vector2(float(data.get("x", _default_position().x)), float(data.get("y", _default_position().y)))
		_panel_visible = bool(data.get("visible", true))
	if _panel != null:
		_panel.visible = _panel_visible


func _save_state() -> void:
	if _panel == null:
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"x": _panel.position.x,
		"y": _panel.position.y,
		"visible": _panel_visible,
	}))
	file.close()


func _set_quick_timer(minutes: int) -> void:
	_hour_spin.value = 0
	_minute_spin.value = minutes
	_second_spin.value = 0
	_start_timer()


func _start_timer() -> void:
	_timer_title = _timer_title_edit.text.strip_edges()
	if _timer_title.is_empty():
		_timer_title = "倒计时提醒"
	_timer_remaining = float(int(_hour_spin.value) * 3600 + int(_minute_spin.value) * 60 + int(_second_spin.value))
	if _timer_remaining <= 0.0:
		_timer_status.text = "请先设置一个大于 0 的时间。"
		return
	_timer_running = true
	set_process(true)
	_timer_status.text = "计时中：%s" % _timer_title
	_refresh_timer_label()


func _pause_timer() -> void:
	_timer_running = false
	set_process(false)
	_timer_status.text = "已暂停。"


func _reset_timer() -> void:
	_timer_running = false
	set_process(false)
	_timer_remaining = 0.0
	_refresh_timer_label()
	_timer_status.text = "已重置。"


func _refresh_timer_label() -> void:
	var total := int(ceil(_timer_remaining))
	_timer_label.text = "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


func _show_timer_alert() -> void:
	_timer_status.text = "时间到了：%s" % _timer_title
	if _timer_dialog != null:
		_timer_dialog.dialog_text = "时间到了：%s" % _timer_title
		_timer_dialog.popup_centered()


func _make_spin(min_value: int, max_value: int, value: int, suffix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.suffix = suffix
	spin.custom_minimum_size = Vector2(82, 0)
	if _font != null:
		spin.add_theme_font_override("font", _font)
	return spin


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_tool_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	if _font != null:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	_apply_button_style(btn)
	return btn


func _apply_panel_style(panel: Panel, bg: Color, radius: int, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)


func _apply_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.18, 0.32, 0.96)
	normal.set_corner_radius_all(8)
	normal.border_color = Color(0.42, 0.6, 0.95, 0.55)
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.27, 0.45, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
