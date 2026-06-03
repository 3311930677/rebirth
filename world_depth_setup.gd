extends RefCounted

class_name WorldDepthSetup

const Y_SORT_SCRIPT := preload("res://y_sort_depth.gd")


static func ensure_y_sort(world_root: Node2D, player_path: NodePath = NodePath("Player")) -> Node:
	var existing: Node = world_root.get_node_or_null("YSortDepth")
	if existing != null:
		return existing
	var sorter := Node.new()
	sorter.name = "YSortDepth"
	sorter.set_script(Y_SORT_SCRIPT)
	world_root.add_child(sorter)
	sorter.set("player_path", player_path)
	return sorter


static func ensure_occlusion_layer(world_root: Node2D) -> Node2D:
	var existing: Node = world_root.get_node_or_null("OcclusionLayers")
	if existing is Node2D:
		return existing as Node2D
	var layer := Node2D.new()
	layer.name = "OcclusionLayers"
	world_root.add_child(layer)
	return layer
