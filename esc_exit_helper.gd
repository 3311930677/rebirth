extends RefCounted

static func is_enter_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				return true
	return false

static func handle_input(
	event: InputEvent,
	esc_confirm_pending: bool,
	return_scene_path: String,
	tree: SceneTree,
	on_pending_changed: Callable,
	before_exit: Callable = Callable()
) -> bool:
	if is_enter_pressed(event) and esc_confirm_pending:
		if before_exit.is_valid():
			before_exit.call()
		tree.change_scene_to_file(return_scene_path)
		return true

	if event.is_action_pressed("ui_cancel"):
		on_pending_changed.call(not esc_confirm_pending)
		return true

	if esc_confirm_pending and event is InputEventKey and event.pressed:
		if not is_enter_pressed(event):
			on_pending_changed.call(false)

	return false

static func hint_text(esc_confirm_pending: bool, idle_text: String, confirm_text: String) -> String:
	if esc_confirm_pending:
		return confirm_text
	return idle_text
