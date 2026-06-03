extends Node2D

var stroke: PackedVector2Array = PackedVector2Array()
var brush_radius: float = 24.0
var is_painting: bool = false


func set_stroke(points: PackedVector2Array, radius: float, painting: bool) -> void:
	stroke = points
	brush_radius = radius
	is_painting = painting
	queue_redraw()


func _draw() -> void:
	if stroke.is_empty():
		return

	if stroke.size() >= 2:
		draw_polyline(stroke, Color(1.0, 0.9, 0.2, 0.95), 3.0, true)

	for point in stroke:
		draw_circle(point, 3.0, Color(1.0, 0.95, 0.4, 1.0))
		draw_arc(point, brush_radius, 0.0, TAU, 24, Color(1.0, 0.55, 0.15, 0.35), 2.0)

	if is_painting and stroke.size() >= 2:
		var preview: PackedVector2Array = MapBlockerPaintUtil.stroke_to_polygon(stroke, brush_radius)
		if preview.size() >= 3:
			draw_colored_polygon(preview, Color(0.95, 0.4, 0.15, 0.22))
			draw_polyline(preview + PackedVector2Array([preview[0]]), Color(1.0, 0.7, 0.2, 0.8), 2.0, true)
