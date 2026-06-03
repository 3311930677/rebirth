extends "res://world_page.gd"

const WorldMapLayout = preload("res://world_map_layout.gd")
const ScheduleUiHelper = preload("res://schedule_ui_helper.gd")

@export var camera_zoom: Vector2 = Vector2(2.85, 2.85)
@export var dream_layout_path: String = "res://data/dream_layout.json"
@export var player_walk_speed: float = 95.0
@export var player_sprite_scale: float = 0.008

@export_group("Player Collision")
@export var show_collision_debug: bool = false
@export var auto_collision_at_feet: bool = true
@export var player_collision_size: Vector2 = Vector2(6, 6):
	set(value):
		player_collision_size = value
		_queue_collision_apply()
@export var player_collision_fine_tune: Vector2 = Vector2.ZERO:
	set(value):
		player_collision_fine_tune = value
		_queue_collision_apply()
@export var player_collision_offset: Vector2 = Vector2(-2.5, -10):
	set(value):
		player_collision_offset = value
		_queue_collision_apply()

var _camera: Camera2D = null


func _ready() -> void:
	super._ready()
	_setup_dream_blockers()
	_camera = $Player/Camera2D as Camera2D
	if _camera != null:
		_camera.zoom = camera_zoom
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = 8.0
	if _player != null:
		_player.speed = player_walk_speed
		_player.collision_debug_visible = show_collision_debug
		_apply_player_collision_shape()
		_player.movement_bounds_sprite = NodePath("../MapBackground")
		_player.refresh_movement_bounds()
	_place_player_at_center()
	_update_dream_hint()


func _restore_world_progress() -> void:
	# dream 每次进入都出生在屏幕正中，不恢复上次坐标
	pass


func _queue_collision_apply() -> void:
	if is_node_ready():
		call_deferred("_apply_player_collision_shape")


func _apply_player_collision_shape() -> void:
	if _player == null:
		return
	var collision := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return

	var offset: Vector2 = player_collision_offset
	if auto_collision_at_feet:
		offset = _compute_feet_collision_center() + player_collision_fine_tune
	else:
		offset = player_collision_offset

	var new_shape := RectangleShape2D.new()
	new_shape.size = player_collision_size.max(Vector2(1.0, 1.0))
	collision.shape = new_shape
	collision.position = offset
	collision.disabled = false

	if _player.has_method("get_collision_debug_rect"):
		_player.queue_redraw()


func _compute_feet_collision_center() -> Vector2:
	var sprite := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return player_collision_offset

	var frame_height: float = 450.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"down"):
		var frame_tex: Texture2D = sprite.sprite_frames.get_frame_texture(&"down", 0)
		if frame_tex != null:
			frame_height = float(frame_tex.get_height())

	# 贴图居中绘制，脚底在 AnimatedSprite2D 中心再往下半个显示高度
	var feet_y: float = sprite.position.y + frame_height * absf(sprite.scale.y) * 0.5
	return Vector2(sprite.position.x, feet_y)


func _place_player_at_center() -> void:
	if _player == null:
		return
	_player.global_position = get_viewport().get_visible_rect().size * 0.5


func _setup_dream_blockers() -> void:
	if _background == null:
		return
	WorldMapLayout.apply_layout(
		self,
		_background,
		dream_layout_path,
		"MapBlockers",
		"OcclusionLayers"
	)


func _update_dream_hint() -> void:
	if _hint == null:
		return
	_hint.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		"WASD 移动  |  Esc 返回世界选择",
		"再按 Enter 确认返回世界选择"
	)
