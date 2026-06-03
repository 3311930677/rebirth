extends Node

## 按脚底 Y 坐标动态设置 z_index，实现角色与遮挡物前后关系。

@export var player_path: NodePath = NodePath("../Player")
@export var sort_offset: int = 0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	var player: Node2D = get_node_or_null(player_path) as Node2D
	if player != null:
		_apply_sort_z(player)

	for occluder in get_tree().get_nodes_in_group("map_occluder"):
		if occluder is Node2D:
			_apply_sort_z(occluder as Node2D)


func _apply_sort_z(node: Node2D) -> void:
	var feet_offset: float = float(node.get_meta("sort_feet_offset", 0.0))
	node.z_index = sort_offset + int(node.global_position.y + feet_offset)
