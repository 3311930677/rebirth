extends RefCounted
class_name MapBlockerPaintUtil

const MIN_POINT_DISTANCE := 6.0
const MIN_POLYGON_POINTS := 3


static func append_stroke_point(stroke: PackedVector2Array, point: Vector2) -> PackedVector2Array:
	if stroke.is_empty():
		return PackedVector2Array([point])
	var last: Vector2 = stroke[stroke.size() - 1]
	if last.distance_to(point) < MIN_POINT_DISTANCE:
		return stroke
	var copy := stroke.duplicate()
	copy.append(point)
	return copy


static func stroke_to_polygon(stroke: PackedVector2Array, radius: float) -> PackedVector2Array:
	if stroke.is_empty():
		return PackedVector2Array()
	if stroke.size() == 1:
		return _circle_polygon(stroke[0], radius, 14)

	var inflated: Array = Geometry2D.offset_polyline(
		stroke,
		radius,
		Geometry2D.JOIN_ROUND,
		Geometry2D.END_ROUND
	)
	if not inflated.is_empty() and inflated[0] is PackedVector2Array:
		var poly: PackedVector2Array = inflated[0]
		if poly.size() >= MIN_POLYGON_POINTS:
			return poly

	return _fallback_thick_stroke(stroke, radius)


static func simplify_polygon(points: PackedVector2Array, tolerance: float = 4.0) -> PackedVector2Array:
	if points.size() < MIN_POLYGON_POINTS:
		return points
	var simplified: PackedVector2Array = _douglas_peucker(points, tolerance)
	if simplified.size() >= MIN_POLYGON_POINTS:
		return simplified
	return points


static func map_local_to_uv_array(map_sprite: Sprite2D, points: PackedVector2Array) -> Array:
	var output: Array = []
	for point in points:
		var uv: Vector2 = WorldMapLayout.local_to_uv(map_sprite, point)
		output.append([snappedf(uv.x, 0.0001), snappedf(uv.y, 0.0001)])
	return output


static func uv_array_to_map_local(map_sprite: Sprite2D, uv_array: Array) -> PackedVector2Array:
	var output := PackedVector2Array()
	for raw in uv_array:
		var uv: Vector2 = _read_uv(raw)
		output.append(WorldMapLayout.uv_to_local(map_sprite, uv))
	return output


static func _douglas_peucker(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var max_dist: float = 0.0
	var index: int = 0
	var end: int = points.size() - 1
	var line_start: Vector2 = points[0]
	var line_end: Vector2 = points[end]
	var line_len_sq: float = line_start.distance_squared_to(line_end)
	for i in range(1, end):
		var dist: float
		if line_len_sq < 0.0001:
			dist = points[i].distance_to(line_start)
		else:
			var t: float = clampf(
				(points[i] - line_start).dot(line_end - line_start) / line_len_sq, 0.0, 1.0
			)
			dist = points[i].distance_to(line_start.lerp(line_end, t))
		if dist > max_dist:
			max_dist = dist
			index = i
	if max_dist > epsilon:
		var left: PackedVector2Array = _douglas_peucker(points.slice(0, index + 1), epsilon)
		var right: PackedVector2Array = _douglas_peucker(points.slice(index, points.size()), epsilon)
		var merged := PackedVector2Array()
		for i in range(left.size() - 1):
			merged.append(left[i])
		for point in right:
			merged.append(point)
		return merged
	return PackedVector2Array([points[0], points[end]])


static func _fallback_thick_stroke(stroke: PackedVector2Array, radius: float) -> PackedVector2Array:
	var cloud := PackedVector2Array()
	for point in stroke:
		cloud.append_array(_circle_polygon(point, radius, 10))
	return Geometry2D.convex_hull(cloud)


static func _circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 8)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _read_uv(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		var arr := value as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(0.5, 0.5)
