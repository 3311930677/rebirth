extends Control

@export var next_scene: String = "res://node_2d.tscn"

func _ready() -> void:
	BgmPlayer.play("firstpage")

func _unhandled_input(event: InputEvent) -> void:
	# 支持 Enter/Space、鼠标左键和方向键/WASD 进入游戏。
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(next_scene)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_tree().change_scene_to_file(next_scene)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file(next_scene)
