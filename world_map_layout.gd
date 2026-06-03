extends RefCounted

class_name WorldMapLayout

const MAP_OCCLUDER_SCENE := preload("res://map_occluder.tscn")


static func apply_layout(
	world_root: Node2D,
	map_background: Sprite2D,
	layout_path: String,
	blockers_parent_name: String = "MapBlockers",
	occluders_parent_name: String = "OcclusionLayers"
) -> void:
	if map_background == null or layout_path.is_empty():
		return

	var layout: Dictionary = _load_layout(layout_path)
	if layout.is_empty():
		return

	var blockers_parent := _ensure_child(map_background, blockers_parent_name)
	var occluders_parent := _ensure_child(world_root, occluders_parent_name)

	for old in blockers_parent.get_children():
		old.queue_free()
	for old in occluders_parent.get_children():
		old.queue_free()

	for entry in layout.get("blockers", []) as Array:
		if entry is Dictionary:
			_spawn_blocker(blockers_parent, map_background, entry)

	for entry in layout.get("occluders", []) as Array:
		if entry is Dictionary:
			_spawn_occluder(occluders_parent, map_background, entry)


static func spawn_occluder_from_blocker(
	occluders_parent: Node2D,
	body: StaticBody2D,
	size_scale: float = 1.0,
	extra_height: float = 40.0
) -> void:
	var shape_node: CollisionShape2D = null
	for child in body.get_children():
		if child is CollisionShape2D:
			shape_node = child as CollisionShape2D
			break
	if shape_node == null or shape_node.shape == null:
		return

	var shape_size := Vector2(80, 60)
	if shape_node.shape is RectangleShape2D:
		shape_size = (shape_node.shape as RectangleShape2D).size

	var occ: Node2D = MAP_OCCLUDER_SCENE.instantiate() as Node2D
	occluders_parent.add_child(occ)
	var occ_size := Vector2(shape_size.x * size_scale, shape_size.y * 0.55 + extra_height)
	var foot := body.global_position + shape_node.position
	foot.y += shape_size.y * 0.45
	occ.global_position = foot
	if occ.has_method("configure"):
		occ.call("configure", occ_size, 0.0, false)


static func spawn_occluder_at_map_uv(
	occluders_parent: Node2D,
	map_background: Sprite2D,
	uv_center: Vector2,
	uv_size: Vector2,
	feet_offset: float = 0.0,
	debug_tint: bool = false
) -> void:
	if map_background.texture == null:
		return
	var tex_size: Vector2 = map_background.texture.get_size()
	var local_center := Vector2(
		(uv_center.x - 0.5) * tex_size.x,
		(uv_center.y - 0.5) * tex_size.y
	)
	var local_size := Vector2(uv_size.x * tex_size.x, uv_size.y * tex_size.y)
	var world_pos := map_background.to_global(local_center)
	var world_size := local_size * map_background.scale

	var occ: Node2D = MAP_OCCLUDER_SCENE.instantiate() as Node2D
	occluders_parent.add_child(occ)
	occ.global_position = world_pos + Vector2(0.0, local_size.y * 0.35 * map_background.scale.y)
	if occ.has_method("configure"):
		occ.call("configure", world_size, feet_offset, debug_tint)


static func uv_to_local(map_bg: Sprite2D, uv: Vector2) -> Vector2:
	return _uv_to_local(map_bg, uv)


static func _spawn_blocker(parent: Node2D, map_bg: Sprite2D, entry: Dictionary) -> void:
	var body := StaticBody2D.new()
	body.name = str(entry.get("name", "Blocker"))
	parent.add_child(body)

	if entry.has("polygon_uv"):
		_spawn_polygon_blocker(body, map_bg, entry.get("polygon_uv", []) as Array)
		return

	var shape := RectangleShape2D.new()
	var size: Vector2 = _read_vec2(entry.get("size", null), Vector2(64, 64))
	shape.size = size

	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	var pos: Vector2 = _read_vec2(entry.get("pos", null), Vector2.ZERO)
	if entry.has("uv"):
		pos = _uv_to_local(map_bg, _read_vec2(entry.get("uv", null), Vector2(0.5, 0.5)))
		var uv_size: Vector2 = _read_vec2(entry.get("uv_size", null), Vector2(0.05, 0.05))
		size = Vector2(uv_size.x * map_bg.texture.get_size().x, uv_size.y * map_bg.texture.get_size().y)
		shape.size = size
	body.position = pos
	col.position = Vector2.ZERO


static func _spawn_polygon_blocker(body: StaticBody2D, map_bg: Sprite2D, polygon_uv: Array) -> void:
	var points := PackedVector2Array()
	for raw_point in polygon_uv:
		points.append(_uv_to_local(map_bg, _read_vec2(raw_point, Vector2(0.5, 0.5))))
	if points.size() < 3:
		return

	body.position = Vector2.ZERO
	var convex_parts: Array = Geometry2D.decompose_polygon_in_convex(points)
	if convex_parts.is_empty():
		convex_parts = [points]
	for part in convex_parts:
		if not part is PackedVector2Array:
			continue
		var convex_points: PackedVector2Array = part as PackedVector2Array
		if convex_points.size() < 3:
			continue
		var shape := ConvexPolygonShape2D.new()
		shape.points = convex_points
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)


static func _spawn_occluder(parent: Node2D, map_bg: Sprite2D, entry: Dictionary) -> void:
	var uv: Vector2 = _read_vec2(entry.get("uv", null), Vector2(0.5, 0.5))
	var uv_size: Vector2 = _read_vec2(entry.get("uv_size", null), Vector2(0.08, 0.1))
	var feet: float = float(entry.get("feet_offset", 0.0))
	spawn_occluder_at_map_uv(parent, map_bg, uv, uv_size, feet, bool(entry.get("debug", false)))


static func _uv_to_local(map_bg: Sprite2D, uv: Vector2) -> Vector2:
	var tex_size: Vector2 = map_bg.texture.get_size()
	return Vector2((uv.x - 0.5) * tex_size.x, (uv.y - 0.5) * tex_size.y)


static func uv_size_to_local(map_bg: Sprite2D, uv_size: Vector2) -> Vector2:
	if map_bg == null or map_bg.texture == null:
		return Vector2(64, 64)
	var tex_size: Vector2 = map_bg.texture.get_size()
	return Vector2(uv_size.x * tex_size.x, uv_size.y * tex_size.y)


static func local_to_uv(map_bg: Sprite2D, local: Vector2) -> Vector2:
	if map_bg == null or map_bg.texture == null:
		return Vector2(0.5, 0.5)
	var tex_size: Vector2 = map_bg.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return Vector2(local.x / tex_size.x + 0.5, local.y / tex_size.y + 0.5)


static func local_size_to_uv(map_bg: Sprite2D, local_size: Vector2) -> Vector2:
	if map_bg == null or map_bg.texture == null:
		return local_size
	var tex_size: Vector2 = map_bg.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return local_size
	return Vector2(local_size.x / tex_size.x, local_size.y / tex_size.y)


static func load_layout(path: String) -> Dictionary:
	return _load_layout(path)


static func save_layout(path: String, layout: Dictionary) -> Error:
	var blockers: Array = layout.get("blockers", []) as Array
	var entry_lines: PackedStringArray = PackedStringArray()
	for raw_entry in blockers:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if entry.is_empty():
			continue
		var entry_name: String = str(entry.get("name", "Blocker"))
		if entry.has("polygon_uv"):
			entry_lines.append(_format_polygon_entry(entry_name, entry.get("polygon_uv", []) as Array))
			continue
		var uv: Vector2 = _read_vec2(entry.get("uv", null), Vector2(0.5, 0.5))
		var uv_size: Vector2 = _read_vec2(entry.get("uv_size", null), Vector2(0.05, 0.05))
		entry_lines.append(
			"    {\"name\": \"%s\", \"uv\": [%.4f, %.4f], \"uv_size\": [%.4f, %.4f]}"
			% [entry_name, uv.x, uv.y, uv_size.x, uv_size.y]
		)
	var lines: PackedStringArray = PackedStringArray(["{", "  \"blockers\": ["])
	for i in range(entry_lines.size()):
		var suffix: String = "," if i < entry_lines.size() - 1 else ""
		lines.append(entry_lines[i] + suffix)
	lines.append("  ]")
	lines.append("}")
	var save_path: String = _resolve_layout_path(path)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入布局文件: %s (err=%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return OK


static func _ensure_child(parent: Node, child_name: String) -> Node2D:
	var existing: Node = parent.get_node_or_null(child_name)
	if existing is Node2D:
		return existing as Node2D
	var node := Node2D.new()
	node.name = child_name
	parent.add_child(node)
	return node


static func _resolve_layout_path(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _load_layout(path: String) -> Dictionary:
	var disk_path: String = _resolve_layout_path(path)
	if not FileAccess.file_exists(disk_path):
		push_warning("布局文件不存在: %s" % path)
		return {}

	var file := FileAccess.open(disk_path, FileAccess.READ)
	if file == null:
		push_warning("无法读取布局文件: %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("布局 JSON 解析失败: %s" % path)
		return {}
	if not parsed is Dictionary:
		push_warning("布局 JSON 格式错误（需要对象）: %s" % path)
		return {}
	return parsed as Dictionary


static func _format_polygon_entry(entry_name: String, polygon_uv: Array) -> String:
	var point_chunks: PackedStringArray = PackedStringArray()
	for raw_point in polygon_uv:
		var uv: Vector2 = _read_vec2(raw_point, Vector2(0.5, 0.5))
		point_chunks.append("[%.4f, %.4f]" % [uv.x, uv.y])
	var points_text: String = ", ".join(point_chunks)
	return "    {\"name\": \"%s\", \"polygon_uv\": [%s]}" % [entry_name, points_text]


static func _read_vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		var arr := value as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback
