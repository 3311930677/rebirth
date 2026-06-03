@tool
extends EditorPlugin

const EDITOR_SCENE := "res://tools/dream_blocker_editor.tscn"


func _enter_tree() -> void:
	add_tool_menu_item("Dream 碰撞箱编辑器", _open_editor)


func _exit_tree() -> void:
	remove_tool_menu_item("Dream 碰撞箱编辑器")


func _open_editor() -> void:
	EditorInterface.open_scene_from_path(EDITOR_SCENE)
	EditorInterface.play_main_scene()
