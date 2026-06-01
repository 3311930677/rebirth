extends RefCounted

const POPUP_LAYER_NAME := "__EscExitPopupLayer"
const POPUP_PANEL_NAME := "ConfirmPanel"
const POPUP_TITLE_NAME := "TitleLabel"
const POPUP_HINT_NAME := "HintLabel"
const DEFAULT_POPUP_TITLE := "是否退出？"
const DEFAULT_POPUP_HINT := "Esc 取消退出    Enter 确定退出"

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
	before_exit: Callable = Callable(),
	popup_owner: Node = null,
	confirm_action: Callable = Callable(),
	popup_title: String = DEFAULT_POPUP_TITLE,
	popup_hint: String = DEFAULT_POPUP_HINT
) -> bool:
	if is_enter_pressed(event) and esc_confirm_pending:
		if before_exit.is_valid():
			before_exit.call()
		if confirm_action.is_valid():
			confirm_action.call()
		elif not return_scene_path.is_empty():
			tree.change_scene_to_file(return_scene_path)
		on_pending_changed.call(false)
		set_popup_visible(popup_owner, false, popup_title, popup_hint)
		return true

	if event.is_action_pressed("ui_cancel"):
		var next_pending: bool = not esc_confirm_pending
		on_pending_changed.call(next_pending)
		set_popup_visible(popup_owner, next_pending, popup_title, popup_hint)
		return true

	if esc_confirm_pending and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not is_enter_pressed(event):
			on_pending_changed.call(false)
			set_popup_visible(popup_owner, false, popup_title, popup_hint)

	return false

static func hint_text(esc_confirm_pending: bool, idle_text: String, confirm_text: String) -> String:
	if esc_confirm_pending:
		return confirm_text
	return idle_text


static func set_popup_visible(
	popup_owner: Node,
	visible: bool,
	popup_title: String = DEFAULT_POPUP_TITLE,
	popup_hint: String = DEFAULT_POPUP_HINT
) -> void:
	if popup_owner == null:
		return
	var layer: CanvasLayer = _ensure_popup_layer(popup_owner)
	if layer == null:
		return
	var title_label: Label = layer.get_node_or_null("%s/%s" % [POPUP_PANEL_NAME, POPUP_TITLE_NAME]) as Label
	var hint_label: Label = layer.get_node_or_null("%s/%s" % [POPUP_PANEL_NAME, POPUP_HINT_NAME]) as Label
	if title_label != null:
		title_label.text = popup_title
	if hint_label != null:
		hint_label.text = popup_hint
	layer.visible = visible


static func _ensure_popup_layer(popup_owner: Node) -> CanvasLayer:
	var existing: CanvasLayer = popup_owner.get_node_or_null(POPUP_LAYER_NAME) as CanvasLayer
	if existing != null:
		return existing

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = POPUP_LAYER_NAME
	layer.visible = false
	popup_owner.add_child(layer)

	var dimmer: ColorRect = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.52)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dimmer)

	var panel: Panel = Panel.new()
	panel.name = POPUP_PANEL_NAME
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_top = -80.0
	panel.offset_right = 220.0
	panel.offset_bottom = 80.0
	layer.add_child(panel)

	var title_label: Label = Label.new()
	title_label.name = POPUP_TITLE_NAME
	title_label.anchor_left = 0.0
	title_label.anchor_top = 0.0
	title_label.anchor_right = 1.0
	title_label.anchor_bottom = 0.5
	title_label.offset_left = 16.0
	title_label.offset_top = 16.0
	title_label.offset_right = -16.0
	title_label.offset_bottom = -4.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	panel.add_child(title_label)

	var hint_label: Label = Label.new()
	hint_label.name = POPUP_HINT_NAME
	hint_label.anchor_left = 0.0
	hint_label.anchor_top = 0.5
	hint_label.anchor_right = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = 16.0
	hint_label.offset_top = 6.0
	hint_label.offset_right = -16.0
	hint_label.offset_bottom = -16.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(hint_label)

	return layer
