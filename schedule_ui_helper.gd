extends RefCounted


static func bind_calendar(
	calendar: Control,
	on_closed: Callable,
	schedule_button: Button = null,
	toggle_callable: Callable = Callable()
) -> void:
	if calendar == null:
		return
	calendar.visible = false
	if calendar.has_signal("closed") and on_closed.is_valid():
		if not calendar.closed.is_connected(on_closed):
			calendar.closed.connect(on_closed)
	if schedule_button != null and toggle_callable.is_valid():
		if not schedule_button.pressed.is_connected(toggle_callable):
			schedule_button.pressed.connect(toggle_callable)


static func toggle(
	calendar: Control,
	player: CharacterBody2D = null,
	pause_player_when_open: bool = true
) -> bool:
	if calendar == null:
		return false
	if calendar.visible:
		calendar.close_calendar()
	else:
		calendar.open_calendar()
	var is_open := calendar.visible
	if pause_player_when_open and player != null:
		player.set_physics_process(not is_open)
	return is_open


static func handle_open_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_TAB or key_event.keycode == KEY_C:
				return true
	return false


static func hint_closed(base_hint: String) -> String:
	return "%s  |  右上角【日程】或 Tab" % base_hint


static func hint_open() -> String:
	return "Esc / Tab 关闭日程  |  ◀▶ 切换月份"
