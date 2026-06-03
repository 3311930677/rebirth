extends Node2D

## 遮挡层：脚底 sort 线以下不绘制，角色 Y 更小时被挡住。

@export var occluder_size: Vector2 = Vector2(120.0, 90.0)
@export var sort_feet_offset: float = 0.0
@export var show_debug_tint: bool = false
@export var debug_color: Color = Color(0.45, 0.32, 0.72, 0.22)

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group("map_occluder")
	set_meta("sort_feet_offset", sort_feet_offset)
	_apply_visual()


func configure(size: Vector2, feet_offset: float, tint_visible: bool = false) -> void:
	occluder_size = size
	sort_feet_offset = feet_offset
	show_debug_tint = tint_visible
	set_meta("sort_feet_offset", sort_feet_offset)
	if is_node_ready():
		_apply_visual()


func _apply_visual() -> void:
	if _visual == null:
		return
	_visual.size = occluder_size
	_visual.position = Vector2(-occluder_size.x * 0.5, -occluder_size.y)
	_visual.color = debug_color if show_debug_tint else Color(0, 0, 0, 0)
	_visual.visible = show_debug_tint
