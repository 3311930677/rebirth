extends Control

@export var next_scene: String = "res://node_2d.tscn"

func _ready() -> void:
	BgmPlayer.play("firstpage")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(next_scene)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_W, KEY_A, KEY_S, KEY_D:
				get_tree().change_scene_to_file(next_scene)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file(next_scene)
