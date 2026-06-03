extends Node2D

const WorldMapLayout = preload("res://world_map_layout.gd")
const MapBlockerHandle = preload("res://tools/map_blocker_handle.gd")
const MapBlockerPaintUtil = preload("res://tools/map_blocker_paint_util.gd")

enum EditMode { SELECT, RECT, PAINT }

@export var layout_path: String = "res://data/dream_layout.json"
@export var map_texture: Texture2D = preload("res://Sprite/dream-map.png")
@export var snap_uv_step: float = 0.0025
@export var paint_brush_radius: float = 28.0

@onready var _map: Sprite2D = $MapBackground
@onready var _blockers_root: Node2D = $Blockers
@onready var _camera: Camera2D = $Camera2D
@onready var _paint_preview: Node2D = $PaintPreview
@onready var _list: ItemList = $UI/Panel/Margin/VBox/BlockerList
@onready var _name_edit: LineEdit = $UI/Panel/Margin/VBox/NameEdit
@onready var _status: Label = $UI/Panel/Margin/VBox/Status
@onready var _hint: Label = $UI/HintBar/Hint
@onready var _mode_select: Button = $UI/Panel/Margin/VBox/ModeRow/SelectModeButton
@onready var _mode_rect: Button = $UI/Panel/Margin/VBox/ModeRow/RectModeButton
@onready var _mode_paint: Button = $UI/Panel/Margin/VBox/ModeRow/PaintModeButton
@onready var _brush_slider: HSlider = $UI/Panel/Margin/VBox/BrushRow/BrushSlider

var _handles: Array[MapBlockerHandle] = []
var _selected: MapBlockerHandle = null
var _edit_mode: EditMode = EditMode.SELECT
var _dragging := false
var _panning := false
var _painting := false
var _paint_stroke: PackedVector2Array = PackedVector2Array()
var _pan_start := Vector2.ZERO
var _camera_start := Vector2.ZERO
var _polygon_counter := 1


func _ready() -> void:
	if map_texture != null:
		_map.texture = map_texture
	_camera.make_current()
	_wire_ui()
	_set_edit_mode(EditMode.SELECT)
	_reload_layout()
	_update_hint()


func _wire_ui() -> void:
	$UI/Panel/Margin/VBox/SaveButton.pressed.connect(_on_save_pressed)
	$UI/Panel/Margin/VBox/ReloadButton.pressed.connect(_reload_layout)
	$UI/Panel/Margin/VBox/AddButton.pressed.connect(_on_add_pressed)
	$UI/Panel/Margin/VBox/DeleteButton.pressed.connect(_on_delete_pressed)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_list.item_selected.connect(_on_list_selected)
	_mode_select.pressed.connect(func() -> void: _set_edit_mode(EditMode.SELECT))
	_mode_rect.pressed.connect(func() -> void: _set_edit_mode(EditMode.RECT))
	_mode_paint.pressed.connect(func() -> void: _set_edit_mode(EditMode.PAINT))
	_brush_slider.value_changed.connect(_on_brush_changed)
	_brush_slider.value = paint_brush_radius
	_on_brush_changed(paint_brush_radius)


func _set_edit_mode(mode: EditMode) -> void:
	_edit_mode = mode
	_cancel_paint_preview()
	_mode_select.button_pressed = mode == EditMode.SELECT
	_mode_rect.button_pressed = mode == EditMode.RECT
	_mode_paint.button_pressed = mode == EditMode.PAINT
	_brush_slider.editable = mode == EditMode.PAINT
	_update_hint()


func _on_brush_changed(value: float) -> void:
	paint_brush_radius = value
	if _paint_preview.has_method("set_stroke"):
		_paint_preview.set_stroke(_paint_stroke, paint_brush_radius, _painting)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_S:
				if key_event.ctrl_pressed or key_event.meta_pressed:
					_save_layout()
					get_viewport().set_input_as_handled()
			KEY_N:
				_on_add_pressed()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				_on_delete_pressed()
				get_viewport().set_input_as_handled()
			KEY_R:
				_reload_layout()
				get_viewport().set_input_as_handled()
			KEY_1:
				_set_edit_mode(EditMode.SELECT)
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_edit_mode(EditMode.RECT)
				get_viewport().set_input_as_handled()
			KEY_3:
				_set_edit_mode(EditMode.PAINT)
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.15, 0.15), Vector2(4.0, 4.0))
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom / 1.1).clamp(Vector2(0.15, 0.15), Vector2(4.0, 4.0))
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse_event.pressed
			_pan_start = mouse_event.position
			_camera_start = _camera.position
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_mouse_drag(mouse_event.position)
			else:
				_end_mouse_drag()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _panning:
			var delta: Vector2 = (motion.position - _pan_start) / _camera.zoom
			_camera.position = _camera_start - delta
			get_viewport().set_input_as_handled()
		elif _painting:
			var map_local: Vector2 = _pointer_map_local(motion.position)
			_paint_stroke = MapBlockerPaintUtil.append_stroke_point(_paint_stroke, map_local)
			_update_paint_preview()
			get_viewport().set_input_as_handled()
		elif _dragging and _selected != null:
			var map_local: Vector2 = _pointer_map_local(motion.position)
			_selected.update_drag(map_local, snap_uv_step)
			_sync_list_item(_selected)
			_update_status()
			get_viewport().set_input_as_handled()


func _begin_mouse_drag(screen_pos: Vector2) -> void:
	if _edit_mode == EditMode.PAINT:
		_begin_paint_stroke(screen_pos)
		return

	var world_pos: Vector2 = _screen_to_world(screen_pos)
	var map_local: Vector2 = _map.to_local(world_pos)
	var hit_scale: float = 1.0 / _camera.zoom.x

	if _selected != null and is_instance_valid(_selected):
		var selected_local: Vector2 = _selected.to_local(world_pos)
		if _selected.try_begin_drag(selected_local, map_local, hit_scale):
			_dragging = true
			return

	for i in range(_handles.size() - 1, -1, -1):
		var handle: MapBlockerHandle = _handles[i]
		if handle == _selected:
			continue
		var handle_local: Vector2 = handle.to_local(world_pos)
		if handle.try_begin_drag(handle_local, map_local, hit_scale):
			_select_handle(handle)
			_dragging = true
			return

	if _edit_mode == EditMode.RECT:
		_on_add_pressed()
		_selected.try_begin_drag(_selected.to_local(world_pos), map_local, hit_scale)
		_dragging = true
		return

	_select_handle(null)


func _begin_paint_stroke(screen_pos: Vector2) -> void:
	_painting = true
	_paint_stroke = PackedVector2Array([_pointer_map_local(screen_pos)])
	_update_paint_preview()


func _end_mouse_drag() -> void:
	if _painting:
		_finish_paint_stroke()
		return
	if _selected != null:
		_selected.end_drag()
	_dragging = false


func _finish_paint_stroke() -> void:
	_painting = false
	var polygon: PackedVector2Array = MapBlockerPaintUtil.stroke_to_polygon(
		_paint_stroke, paint_brush_radius
	)
	polygon = MapBlockerPaintUtil.simplify_polygon(polygon, 3.0)
	_cancel_paint_preview()

	if polygon.size() < 3:
		_set_status("涂鸦太短，未生成碰撞箱")
		return

	var entry_name: String = "Paint_%d" % _polygon_counter
	_polygon_counter += 1
	var handle: MapBlockerHandle = _add_polygon_handle(entry_name, polygon)
	_select_handle(handle)
	_rebuild_list()
	_set_status("已添加涂鸦碰撞: %s（%d 顶点）" % [entry_name, polygon.size()])


func _cancel_paint_preview() -> void:
	_painting = false
	_paint_stroke = PackedVector2Array()
	_update_paint_preview()


func _update_paint_preview() -> void:
	if _paint_preview.has_method("set_stroke"):
		_paint_preview.set_stroke(_paint_stroke, paint_brush_radius, _painting)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if _camera != null:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		return _camera.global_position + (screen_pos - viewport_size * 0.5) / _camera.zoom
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _pointer_map_local(screen_pos: Vector2) -> Vector2:
	return _map.to_local(_screen_to_world(screen_pos))


func _reload_layout() -> void:
	_clear_handles()
	_polygon_counter = 1
	var layout: Dictionary = WorldMapLayout.load_layout(layout_path)
	for entry in layout.get("blockers", []) as Array:
		if entry is Dictionary:
			_add_handle(entry as Dictionary)
			var entry_name: String = str((entry as Dictionary).get("name", ""))
			if entry_name.begins_with("Paint_"):
				var suffix: String = entry_name.trim_prefix("Paint_")
				if suffix.is_valid_int():
					_polygon_counter = maxi(_polygon_counter, int(suffix) + 1)
	_rebuild_list()
	_select_handle(null)
	_set_status("已加载 %d 个碰撞箱" % _handles.size())


func _save_layout() -> void:
	var blockers: Array = []
	for handle in _handles:
		blockers.append(handle.to_entry())
	var err: Error = WorldMapLayout.save_layout(layout_path, {"blockers": blockers})
	if err != OK:
		_set_status("保存失败: %s" % error_string(err))
		return
	_set_status("已保存到 %s" % layout_path)


func _on_save_pressed() -> void:
	_save_layout()


func _on_add_pressed() -> void:
	var entry := {
		"name": "Blocker_%d" % (_handles.size() + 1),
		"uv": [0.5, 0.5],
		"uv_size": [0.06, 0.06],
	}
	var handle := _add_handle(entry)
	_select_handle(handle)
	_rebuild_list()
	_set_status("已新增矩形碰撞箱")


func _on_delete_pressed() -> void:
	if _selected == null:
		return
	var handle := _selected
	_select_handle(null)
	handle.queue_free()
	_handles.erase(handle)
	_rebuild_list()
	_set_status("已删除碰撞箱")


func _on_name_submitted(new_name: String) -> void:
	if _selected == null:
		return
	var trimmed: String = new_name.strip_edges()
	if trimmed.is_empty():
		return
	_selected.blocker_name = trimmed
	_selected.name = trimmed
	_selected.queue_redraw()
	_rebuild_list()
	_select_handle(_selected)


func _on_list_selected(index: int) -> void:
	if index < 0 or index >= _handles.size():
		return
	_select_handle(_handles[index])


func _add_handle(entry: Dictionary) -> MapBlockerHandle:
	var handle: MapBlockerHandle = MapBlockerHandle.new()
	handle.setup(_map, entry)
	handle.changed.connect(_on_handle_changed)
	handle.selected.connect(_on_handle_selected)
	_blockers_root.add_child(handle)
	_handles.append(handle)
	return handle


func _add_polygon_handle(entry_name: String, points: PackedVector2Array) -> MapBlockerHandle:
	var handle: MapBlockerHandle = MapBlockerHandle.new()
	handle.setup_polygon(_map, entry_name, points)
	handle.changed.connect(_on_handle_changed)
	handle.selected.connect(_on_handle_selected)
	_blockers_root.add_child(handle)
	_handles.append(handle)
	return handle


func _clear_handles() -> void:
	for handle in _handles:
		handle.queue_free()
	_handles.clear()
	_selected = null


func _select_handle(handle: MapBlockerHandle) -> void:
	if _selected != null:
		_selected.set_selected(false)
	_selected = handle
	if _selected != null:
		_selected.set_selected(true)
		_name_edit.text = _selected.blocker_name
		var index: int = _handles.find(_selected)
		if index >= 0:
			_list.select(index)
	else:
		_name_edit.text = ""
		_list.deselect_all()
	_update_status()


func _on_handle_changed(handle: MapBlockerHandle) -> void:
	_sync_list_item(handle)
	_update_status()


func _on_handle_selected(handle: MapBlockerHandle) -> void:
	_select_handle(handle)


func _rebuild_list() -> void:
	_list.clear()
	for handle in _handles:
		_list.add_item(_format_list_label(handle))


func _sync_list_item(handle: MapBlockerHandle) -> void:
	var index: int = _handles.find(handle)
	if index < 0:
		return
	_list.set_item_text(index, _format_list_label(handle))


func _format_list_label(handle: MapBlockerHandle) -> String:
	if handle.shape_kind == MapBlockerHandle.ShapeKind.POLYGON:
		return "%s  [涂鸦 %d点]" % [handle.blocker_name, handle.polygon_local.size()]
	return "%s  (%.3f, %.3f)  %.3f×%.3f" % [
		handle.blocker_name,
		handle.uv.x,
		handle.uv.y,
		handle.uv_size.x,
		handle.uv_size.y,
	]


func _set_status(text: String) -> void:
	_status.text = text


func _update_status() -> void:
	if _selected == null:
		_set_status("未选中")
		return
	if _selected.shape_kind == MapBlockerHandle.ShapeKind.POLYGON:
		_set_status(
			"选中涂鸦: %s | %d 个顶点"
			% [_selected.blocker_name, _selected.polygon_local.size()]
		)
		return
	_set_status(
		"选中矩形: %s | uv=(%.4f, %.4f) | size=(%.4f, %.4f)"
		% [_selected.blocker_name, _selected.uv.x, _selected.uv.y, _selected.uv_size.x, _selected.uv_size.y]
	)


func _update_hint() -> void:
	match _edit_mode:
		EditMode.PAINT:
			_hint.text = (
				"【涂鸦模式】按住左键涂抹 | 画笔滑条调粗细 | 中键平移 | 滚轮缩放 | Ctrl+S 保存 | 1/2/3 切换模式"
			)
		EditMode.RECT:
			_hint.text = (
				"【矩形模式】左键点空白处新建 | 拖拽移动/拉角 | 中键平移 | Ctrl+S 保存 | 1/2/3 切换模式"
			)
		_:
			_hint.text = (
				"【选择模式】左键选中并拖拽 | 中键平移 | 滚轮缩放 | Ctrl+S 保存 | 3=涂鸦 2=矩形 | Del 删除"
			)
