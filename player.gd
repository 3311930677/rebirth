extends CharacterBody2D

@export var speed: float = 250.0
@export var walk_fps: float = 10.0
@export var rest_fps: float = 4.0
@export var sprite_scale: float = 0.24
@export var rest_scale_multiplier: float = 0.9
@export var begin_sign_path: NodePath = NodePath("../DoorSigns/BeginSign")
@export var begin_trigger_distance: float = 120.0
@export var sky_scene_path: String = "res://sky_select.tscn"
@export var task_sign_path: NodePath = NodePath("../DoorSigns/TaskSign")
@export var task_trigger_distance: float = 120.0
@export var task_scene_path: String = "res://task_board.tscn"

@export var movement_bounds_margin: float = 16.0
@export var movement_bounds_sprite: NodePath = NodePath("../MapBackground")
@export var enable_scene_triggers: bool = true

const SHEET_PATHS := {
	&"down": "res://Sprite/down.png",
	&"up": "res://Sprite/up.png",
	&"left": "res://Sprite/left.png",
	&"right": "res://Sprite/right.png",
	&"rest": "res://Sprite/rest.png",
}

const REST_FRAME_RECTS = [
	Rect2i(1, 1, 251, 448),
	Rect2i(333, 2, 244, 447),
	Rect2i(687, 2, 247, 447),
	Rect2i(1041, 2, 248, 447),
]

const REST_FACING_FRAME := {
	&"down": 0,
	&"up": 1,
	&"right": 2,
	&"left": 3,
}

const WALK_BLOB_MIN_AREA := 20000
const WALK_BLOB_ALPHA := 30.0 / 255.0

var _input_dir := Vector2.ZERO
var _last_facing: StringName = &"down"
var _world_bounds: Rect2 = Rect2()
var _begin_sign: Node2D = null
var _task_sign: Node2D = null
var _is_switching_scene := false

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_setup_direction_animations()
	_compute_world_bounds()
	if enable_scene_triggers:
		_begin_sign = get_node_or_null(begin_sign_path) as Node2D
		_task_sign = get_node_or_null(task_sign_path) as Node2D
	_play_idle()

func refresh_movement_bounds() -> void:
	_compute_world_bounds()

func get_collision_half_extents() -> Vector2:
	return _get_collision_half_extents()

func _physics_process(_delta: float) -> void:
	var x := int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	var y := int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	_input_dir = Vector2(x, y)

	if _input_dir.length_squared() > 0.0:
		_input_dir = _input_dir.normalized()

	velocity = _input_dir * speed
	move_and_slide()
	_clamp_to_bounds()
	_update_animation()
	if enable_scene_triggers:
		_check_enter_sky()
		_check_enter_task()

func _compute_world_bounds() -> void:
	var s := get_node_or_null(movement_bounds_sprite) as Sprite2D
	if s == null or s.texture == null:
		_world_bounds = Rect2(Vector2(-100000, -100000), Vector2(200000, 200000))
		return

	var tex_size := s.texture.get_size()
	var size := tex_size * s.global_scale
	var half := size * 0.5
	_world_bounds = Rect2(s.global_position - half, size)

func _clamp_to_bounds() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return

	var m := movement_bounds_margin
	var half := _get_collision_half_extents()
	var min_x := _world_bounds.position.x + m + half.x
	var min_y := _world_bounds.position.y + m + half.y
	var max_x := _world_bounds.position.x + _world_bounds.size.x - m - half.x
	var max_y := _world_bounds.position.y + _world_bounds.size.y - m - half.y

	global_position = Vector2(
		clampf(global_position.x, min_x, max_x),
		clampf(global_position.y, min_y, max_y)
	)

func _get_collision_half_extents() -> Vector2:
	if _collision_shape == null or _collision_shape.shape == null:
		return Vector2.ZERO

	var shape := _collision_shape.shape
	var scaled := _collision_shape.global_scale

	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size * 0.5 * scaled
	if shape is CircleShape2D:
		var r := (shape as CircleShape2D).radius
		return Vector2(r * scaled.x, r * scaled.y)
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		var half_h := (cap.height * 0.5) + cap.radius
		return Vector2(cap.radius * scaled.x, half_h * scaled.y)

	return Vector2.ZERO

func _setup_direction_animations() -> void:
	var frames := SpriteFrames.new()

	for anim in [&"down", &"up", &"left", &"right"]:
		_add_walk_animation(frames, anim, SHEET_PATHS[anim], walk_fps)

	_add_rest_animation(frames)

	_animated_sprite.sprite_frames = frames
	_animated_sprite.centered = true

func _add_walk_animation(
	frames: SpriteFrames,
	anim_name: StringName,
	sheet_path: String,
	fps: float
) -> void:
	var image := _load_sheet_image(sheet_path)
	if image == null:
		return

	var rects := _detect_walk_frame_rects(image)
	if rects.size() < 2:
		push_error("未在贴图中检测到有效行走帧: %s" % sheet_path)
		return

	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, fps)
	_add_normalized_frames(frames, anim_name, image, rects)

func _add_rest_animation(frames: SpriteFrames) -> void:
	var image := _load_sheet_image(SHEET_PATHS[&"rest"])
	if image == null:
		return

	frames.add_animation(&"rest")
	frames.set_animation_loop(&"rest", false)
	frames.set_animation_speed(&"rest", rest_fps)
	_add_normalized_frames(frames, &"rest", image, REST_FRAME_RECTS)

func _load_sheet_image(sheet_path: String) -> Image:
	var texture := load(sheet_path) as Texture2D
	if texture == null:
		push_error("无法加载角色贴图: %s" % sheet_path)
		return null

	var image := texture.get_image()
	if image == null:
		push_error("无法从贴图获取图像: %s" % sheet_path)
		return null

	if image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
	return image

func _detect_walk_frame_rects(image: Image) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)

	var blobs: Array = []
	for y in range(height):
		for x in range(width):
			var start_idx := y * width + x
			if visited[start_idx] == 1:
				continue
			if image.get_pixel(x, y).a < WALK_BLOB_ALPHA:
				visited[start_idx] = 1
				continue

			var stack: Array = [Vector2i(x, y)]
			visited[start_idx] = 1
			var min_x := x
			var max_x := x
			var min_y := y
			var max_y := y
			var area := 0

			while not stack.is_empty():
				var point: Vector2i = stack.pop_back()
				area += 1
				min_x = mini(min_x, point.x)
				max_x = maxi(max_x, point.x)
				min_y = mini(min_y, point.y)
				max_y = maxi(max_y, point.y)

				for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var next: Vector2i = point + offset
					if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
						continue
					var next_idx := next.y * width + next.x
					if visited[next_idx] == 1:
						continue
					visited[next_idx] = 1
					if image.get_pixel(next.x, next.y).a >= WALK_BLOB_ALPHA:
						stack.append(next)

			if area >= WALK_BLOB_MIN_AREA:
				blobs.append({
					"rect": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
					"area": area,
				})

	if blobs.is_empty():
		return []

	if blobs.size() > 3:
		blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.area > b.area
		)
		blobs = blobs.slice(0, 3)

	blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.rect.position.x < b.rect.position.x
	)

	var rects: Array = []
	for blob in blobs:
		rects.append(blob.rect)
	return rects

func _add_normalized_frames(frames: SpriteFrames, anim_name: StringName, image: Image, rects: Array) -> void:
	var canvas_w := 0
	var canvas_h := 0
	for rect in rects:
		canvas_w = maxi(canvas_w, rect.size.x)
		canvas_h = maxi(canvas_h, rect.size.y)

	for rect in rects:
		var frame_image := _normalize_frame(image, rect, canvas_w, canvas_h)
		frames.add_frame(anim_name, ImageTexture.create_from_image(frame_image))

func _normalize_frame(source: Image, rect: Rect2i, canvas_w: int, canvas_h: int) -> Image:
	var frame := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0, 0, 0, 0))

	var cropped := source.get_region(rect)
	var dst_x := int((float(canvas_w - rect.size.x)) / 2.0)
	var dst_y := canvas_h - rect.size.y
	frame.blit_rect(cropped, Rect2i(Vector2i.ZERO, rect.size), Vector2i(dst_x, dst_y))
	return frame

func _update_animation() -> void:
	if _animated_sprite.sprite_frames == null:
		return

	if _input_dir == Vector2.ZERO:
		_play_idle()
		return

	if absf(_input_dir.x) > absf(_input_dir.y):
		_last_facing = &"right" if _input_dir.x > 0.0 else &"left"
	else:
		_last_facing = &"down" if _input_dir.y > 0.0 else &"up"

	_play_walk(_last_facing)

func _play_walk(facing: StringName) -> void:
	if not _animated_sprite.sprite_frames.has_animation(facing):
		return

	_apply_walk_scale()

	if _animated_sprite.animation == &"rest" or _animated_sprite.animation != facing:
		_animated_sprite.play(facing)
	elif not _animated_sprite.is_playing():
		_animated_sprite.play(facing)

func _play_idle() -> void:
	if _animated_sprite.sprite_frames == null:
		return

	if not _animated_sprite.sprite_frames.has_animation(&"rest"):
		return

	_apply_rest_scale()

	var rest_frame: int = REST_FACING_FRAME.get(_last_facing, 0)
	rest_frame = clampi(rest_frame, 0, _animated_sprite.sprite_frames.get_frame_count(&"rest") - 1)

	if _animated_sprite.animation != &"rest":
		_animated_sprite.play(&"rest")

	if _animated_sprite.is_playing():
		_animated_sprite.stop()

	_animated_sprite.frame = rest_frame

func _apply_walk_scale() -> void:
	_animated_sprite.scale = Vector2.ONE * sprite_scale

func _apply_rest_scale() -> void:
	_animated_sprite.scale = Vector2.ONE * sprite_scale * rest_scale_multiplier

func _check_enter_sky() -> void:
	if _is_switching_scene:
		return
	if _begin_sign == null:
		return
	if sky_scene_path.is_empty():
		return
	if _input_dir == Vector2.ZERO:
		return

	if global_position.distance_to(_begin_sign.global_position) <= begin_trigger_distance:
		_is_switching_scene = true
		get_tree().change_scene_to_file(sky_scene_path)

func _check_enter_task() -> void:
	if _is_switching_scene:
		return
	if _task_sign == null:
		return
	if task_scene_path.is_empty():
		return
	if _input_dir == Vector2.ZERO:
		return

	if global_position.distance_to(_task_sign.global_position) <= task_trigger_distance:
		_is_switching_scene = true
		get_tree().change_scene_to_file(task_scene_path)
