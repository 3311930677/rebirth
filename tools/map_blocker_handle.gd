class_name MapBlockerHandle
extends Node2D

signal changed(handle: MapBlockerHandle)
signal selected(handle: MapBlockerHandle)

enum ShapeKind { RECT, POLYGON }
enum DragMode { NONE, MOVE, RESIZE_TL, RESIZE_TR, RESIZE_BL, RESIZE_BR }

const HANDLE_RADIUS := 10.0
const HANDLE_HIT_PADDING := 10.0
const MIN_UV_SIZE := Vector2(0.01, 0.01)

var blocker_name: String = "Blocker"
var shape_kind: ShapeKind = ShapeKind.RECT
var uv: Vector2 = Vector2(0.5, 0.5)
var uv_size: Vector2 = Vector2(0.05, 0.05)
var polygon_local: PackedVector2Array = PackedVector2Array()

var is_selected: bool = false
var _map: Sprite2D = null
var _drag_mode: DragMode = DragMode.NONE
var _drag_start_uv: Vector2 = Vector2.ZERO
var _drag_start_uv_size: Vector2 = Vector2.ZERO
var _drag_start_mouse_uv: Vector2 = Vector2.ZERO
var _drag_start_polygon: PackedVector2Array = PackedVector2Array()


func setup(map_sprite: Sprite2D, entry: Dictionary) -> void:
	_map = map_sprite
	blocker_name = str(entry.get("name", "Blocker"))
	name = blocker_name

	if entry.has("polygon_uv"):
		shape_kind = ShapeKind.POLYGON
		polygon_local = MapBlockerPaintUtil.uv_array_to_map_local(
			_map, entry.get("polygon_uv", []) as Array
		)
		position = Vector2.ZERO
	else:
		shape_kind = ShapeKind.RECT
		uv = _read_entry_vec2(entry.get("uv", null), Vector2(0.5, 0.5))
		uv_size = _read_entry_vec2(entry.get("uv_size", null), Vector2(0.05, 0.05))
		_sync_transform()

	queue_redraw()


func setup_polygon(map_sprite: Sprite2D, entry_name: String, points: PackedVector2Array) -> void:
	_map = map_sprite
	shape_kind = ShapeKind.POLYGON
	blocker_name = entry_name
	name = entry_name
	polygon_local = points.duplicate()
	position = Vector2.ZERO
	queue_redraw()


func to_entry() -> Dictionary:
	if shape_kind == ShapeKind.POLYGON:
		return {
			"name": blocker_name,
			"polygon_uv": MapBlockerPaintUtil.map_local_to_uv_array(_map, polygon_local),
		}
	return {
		"name": blocker_name,
		"uv": [snappedf(uv.x, 0.0001), snappedf(uv.y, 0.0001)],
		"uv_size": [snappedf(uv_size.x, 0.0001), snappedf(uv_size.y, 0.0001)],
	}


func _sync_transform() -> void:
	if _map == null or shape_kind != ShapeKind.RECT:
		return
	position = WorldMapLayout.uv_to_local(_map, uv)


func get_local_size() -> Vector2:
	if shape_kind == ShapeKind.POLYGON:
		return _polygon_bounds().size
	if _map == null:
		return Vector2(64, 64)
	return WorldMapLayout.uv_size_to_local(_map, uv_size)


func _polygon_bounds() -> Rect2:
	if polygon_local.is_empty():
		return Rect2(Vector2.ZERO, Vector2(64, 64))
	var rect := Rect2(polygon_local[0], Vector2.ZERO)
	for i in range(1, polygon_local.size()):
		rect = rect.expand(polygon_local[i])
	return rect


func _draw() -> void:
	if shape_kind == ShapeKind.POLYGON:
		_draw_polygon_shape()
		return
	_draw_rect_shape()


func _draw_rect_shape() -> void:
	var half: Vector2 = get_local_size() * 0.5
	var rect := Rect2(-half, get_local_size())
	var fill := Color(1.0, 0.35, 0.2, 0.28) if is_selected else Color(0.2, 0.75, 1.0, 0.22)
	var border := Color(1.0, 0.9, 0.3, 0.95) if is_selected else Color(0.45, 0.85, 1.0, 0.85)
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 2.0)

	if is_selected:
		for corner in _corner_points(half):
			draw_circle(corner, HANDLE_RADIUS, Color(1, 1, 0.9, 0.95))
			draw_arc(corner, HANDLE_RADIUS, 0.0, TAU, 16, Color(0.1, 0.1, 0.15, 1.0), 2.0)

	var label_pos := Vector2(-half.x + 4.0, -half.y + 2.0)
	_draw_label(label_pos)


func _draw_polygon_shape() -> void:
	if polygon_local.size() < 3:
		return
	var fill := Color(0.95, 0.45, 0.2, 0.32) if is_selected else Color(0.25, 0.85, 0.55, 0.26)
	var border := Color(1.0, 0.85, 0.35, 0.95) if is_selected else Color(0.5, 1.0, 0.75, 0.9)
	draw_colored_polygon(polygon_local, fill)
	draw_polyline(polygon_local + PackedVector2Array([polygon_local[0]]), border, 2.0, true)
	_draw_label(_polygon_bounds().position + Vector2(4.0, 2.0))


func _draw_label(pos: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, blocker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))


func _corner_points(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


func try_begin_drag(handle_local: Vector2, map_local: Vector2, hit_scale: float = 1.0) -> bool:
	if shape_kind == ShapeKind.POLYGON:
		return _try_begin_polygon_drag(map_local)

	_drag_mode = DragMode.NONE
	var half: Vector2 = get_local_size() * 0.5
	var hit_radius: float = (HANDLE_RADIUS + HANDLE_HIT_PADDING) * maxf(hit_scale, 1.0)

	if handle_local.distance_to(Vector2(-half.x, -half.y)) <= hit_radius:
		_drag_mode = DragMode.RESIZE_TL
	elif handle_local.distance_to(Vector2(half.x, -half.y)) <= hit_radius:
		_drag_mode = DragMode.RESIZE_TR
	elif handle_local.distance_to(Vector2(half.x, half.y)) <= hit_radius:
		_drag_mode = DragMode.RESIZE_BR
	elif handle_local.distance_to(Vector2(-half.x, half.y)) <= hit_radius:
		_drag_mode = DragMode.RESIZE_BL

	if _drag_mode == DragMode.NONE:
		var rect := Rect2(-half, get_local_size())
		if not rect.has_point(handle_local):
			return false
		_drag_mode = DragMode.MOVE

	_begin_drag_state(map_local)
	selected.emit(self)
	return true


func _try_begin_polygon_drag(map_local: Vector2) -> bool:
	if polygon_local.size() < 3:
		return false
	if not Geometry2D.is_point_in_polygon(map_local, polygon_local):
		return false
	_drag_mode = DragMode.MOVE
	_begin_drag_state(map_local)
	selected.emit(self)
	return true


func update_drag(map_local: Vector2, snap_uv: float) -> void:
	if _drag_mode == DragMode.NONE or _map == null:
		return

	if shape_kind == ShapeKind.POLYGON:
		_apply_polygon_move(map_local, snap_uv)
		queue_redraw()
		changed.emit(self)
		return

	var mouse_uv: Vector2 = WorldMapLayout.local_to_uv(_map, map_local)
	match _drag_mode:
		DragMode.MOVE:
			if snap_uv > 0.0:
				mouse_uv = mouse_uv.snapped(Vector2(snap_uv, snap_uv))
			var delta_uv: Vector2 = mouse_uv - _drag_start_mouse_uv
			uv = (_drag_start_uv + delta_uv).clamp(Vector2(0.0, 0.0), Vector2(1.0, 1.0))
		DragMode.RESIZE_TL, DragMode.RESIZE_TR, DragMode.RESIZE_BL, DragMode.RESIZE_BR:
			_apply_resize(mouse_uv)

	_sync_transform()
	queue_redraw()
	changed.emit(self)


func _apply_polygon_move(map_local: Vector2, snap_uv: float) -> void:
	var mouse_uv: Vector2 = WorldMapLayout.local_to_uv(_map, map_local)
	if snap_uv > 0.0:
		mouse_uv = mouse_uv.snapped(Vector2(snap_uv, snap_uv))
	var delta_uv: Vector2 = mouse_uv - _drag_start_mouse_uv
	if _map == null:
		return
	var tex_size: Vector2 = _map.texture.get_size()
	var delta_local := Vector2(delta_uv.x * tex_size.x, delta_uv.y * tex_size.y)
	polygon_local = PackedVector2Array()
	for point in _drag_start_polygon:
		polygon_local.append(point + delta_local)


func end_drag() -> void:
	_drag_mode = DragMode.NONE


func _begin_drag_state(map_local: Vector2) -> void:
	_drag_start_uv = uv
	_drag_start_uv_size = uv_size
	_drag_start_polygon = polygon_local.duplicate()
	if _map != null:
		_drag_start_mouse_uv = WorldMapLayout.local_to_uv(_map, map_local)


func _apply_resize(mouse_uv: Vector2) -> void:
	var min_uv := _drag_start_uv - _drag_start_uv_size * 0.5
	var max_uv := _drag_start_uv + _drag_start_uv_size * 0.5

	match _drag_mode:
		DragMode.RESIZE_TL:
			min_uv = mouse_uv
		DragMode.RESIZE_TR:
			min_uv.y = mouse_uv.y
			max_uv.x = mouse_uv.x
		DragMode.RESIZE_BR:
			max_uv = mouse_uv
		DragMode.RESIZE_BL:
			max_uv.y = mouse_uv.y
			min_uv.x = mouse_uv.x

	if max_uv.x < min_uv.x:
		var swap_x: float = max_uv.x
		max_uv.x = min_uv.x
		min_uv.x = swap_x
	if max_uv.y < min_uv.y:
		var swap_y: float = max_uv.y
		max_uv.y = min_uv.y
		min_uv.y = swap_y

	uv = (min_uv + max_uv) * 0.5
	uv_size = (max_uv - min_uv).max(MIN_UV_SIZE)


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


static func _read_entry_vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		var arr := value as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback
