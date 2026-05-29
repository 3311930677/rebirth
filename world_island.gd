extends "res://world_page.gd"

const WATER_GRID_SIZE := Vector2i(24, 24)
const WATER_CELL_THRESHOLD := 0.55
const WATER_SAMPLE_STEP := 4

const POST_INTRO_LINES: Array[String] = [
	"被抛入这片死寂孤岛，活下去，成了唯一的执念。",
	"好像........活得还挺好，鸡腿好吃QAQ",
]
const POST_INTRO_LINE_DURATION := 4.0

var _post_intro_active := false
var _post_intro_index := 0
var _post_intro_elapsed := 0.0

@onready var _intro_dialogue_panel: Panel = $UI/IntroDialoguePanel
@onready var _intro_dialogue_label: Label = $UI/IntroDialoguePanel/IntroDialogueLabel

func _ready() -> void:
	_setup_intro_dialogue()
	super._ready()
	_build_water_blockers()


func is_intro_video_playing() -> bool:
	return _intro_playing or _post_intro_active


func _process(delta: float) -> void:
	super._process(delta)
	if not _post_intro_active:
		return

	_post_intro_elapsed += delta
	if _post_intro_elapsed < POST_INTRO_LINE_DURATION:
		return

	_post_intro_index += 1
	if _post_intro_index >= POST_INTRO_LINES.size():
		_finish_post_intro_dialogue()
		return

	_post_intro_elapsed = 0.0
	_intro_dialogue_label.text = POST_INTRO_LINES[_post_intro_index]


func _on_intro_sequence_complete() -> void:
	_begin_post_intro_dialogue()


func _begin_post_intro_dialogue() -> void:
	_post_intro_active = true
	_post_intro_index = 0
	_post_intro_elapsed = 0.0
	_intro_dialogue_panel.visible = true
	_intro_dialogue_label.text = POST_INTRO_LINES[0]


func _finish_post_intro_dialogue() -> void:
	_post_intro_active = false
	_intro_dialogue_panel.visible = false
	super._release_player_after_intro()


func _setup_intro_dialogue() -> void:
	_intro_dialogue_panel.visible = false
	var font: FontFile = load("res://HYPixel11pxU-2.ttf") as FontFile
	if font != null:
		_intro_dialogue_label.add_theme_font_override("font", font)
	_intro_dialogue_label.add_theme_font_size_override("font_size", 22)
	_intro_dialogue_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.9)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 8
	_intro_dialogue_panel.add_theme_stylebox_override("panel", panel_style)


func _build_water_blockers() -> void:
	var sprite := _background as Sprite2D
	if sprite == null or sprite.texture == null:
		return

	var image := sprite.texture.get_image()
	if image.is_empty():
		return

	var existing := sprite.get_node_or_null("WaterBlockers")
	if existing != null:
		existing.queue_free()

	var blockers := Node2D.new()
	blockers.name = "WaterBlockers"
	sprite.add_child(blockers)

	var tex_size := image.get_size()
	var tex_w := tex_size.x
	var tex_h := tex_size.y
	var grid_w := WATER_GRID_SIZE.x
	var grid_h := WATER_GRID_SIZE.y
	var grid: Array = []

	for gy in range(grid_h):
		var row: Array[bool] = []
		for gx in range(grid_w):
			row.append(_cell_is_water(image, gx, gy, grid_w, grid_h, tex_w, tex_h))
		grid.append(row)

	for gy in range(grid_h):
		var gx := 0
		while gx < grid_w:
			if not grid[gy][gx]:
				gx += 1
				continue

			var start_gx := gx
			while gx < grid_w and grid[gy][gx]:
				gx += 1

			var x0 := int(float(start_gx * tex_w) / float(grid_w))
			var x1 := int(float(gx * tex_w) / float(grid_w))
			var y0 := int(float(gy * tex_h) / float(grid_h))
			var y1 := int(float((gy + 1) * tex_h) / float(grid_h))
			_add_water_rect(blockers, x0, y0, x1 - x0, y1 - y0, tex_w, tex_h)


func _cell_is_water(
	image: Image,
	gx: int,
	gy: int,
	grid_w: int,
	grid_h: int,
	tex_w: int,
	tex_h: int
) -> bool:
	var x0 := int(float(gx * tex_w) / float(grid_w))
	var x1 := int(float((gx + 1) * tex_w) / float(grid_w))
	var y0 := int(float(gy * tex_h) / float(grid_h))
	var y1 := int(float((gy + 1) * tex_h) / float(grid_h))
	var water_count := 0
	var total := 0

	for y in range(y0, y1, WATER_SAMPLE_STEP):
		for x in range(x0, x1, WATER_SAMPLE_STEP):
			total += 1
			if _is_water_pixel(image.get_pixel(x, y)):
				water_count += 1

	if total == 0:
		return false
	return float(water_count) / float(total) > WATER_CELL_THRESHOLD


func _is_water_pixel(color: Color) -> bool:
	var hue := color.h
	var sat := color.s
	var val := color.v
	var deep_water := (
		hue > 0.45
		and hue < 0.62
		and sat > 0.25
		and val > 0.35
		and val < 0.55
		and color.b > color.r
	)
	var shallow_water := (
		hue > 0.45
		and hue < 0.62
		and sat > 0.15
		and val >= 0.55
		and val < 0.75
		and color.b > color.r + 0.05
	)
	return deep_water or shallow_water


func _add_water_rect(
	parent: Node2D,
	x0: float,
	y0: float,
	width: float,
	height: float,
	tex_w: int,
	tex_h: int
) -> void:
	var body := StaticBody2D.new()
	var shape_node := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(width, height)
	shape_node.shape = rect_shape
	body.position = Vector2(
		x0 + width * 0.5 - tex_w * 0.5,
		y0 + height * 0.5 - tex_h * 0.5
	)
	body.add_child(shape_node)
	parent.add_child(body)
