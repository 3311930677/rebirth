extends Control

const EscExitHelper = preload("res://esc_exit_helper.gd")

@export var sky_background_path: String = "res://Sprite/sky.jpg"
@export var island_option_path: String = "res://Sprite/island.png"
@export var room_option_path: String = "res://Sprite/room.png"
@export var forest_option_path: String = "res://Sprite/forest.png"
@export var dream_option_path: String = "res://Sprite/dream.png"
@export var reality_option_path: String = "res://Sprite/reality.png"
@export var continue_option_path: String = "res://Sprite/continue.png"

@export var island_scene_path: String = "res://world_island.tscn"
@export var room_scene_path: String = "res://world_room.tscn"
@export var forest_scene_path: String = "res://world_forest.tscn"
@export var dream_scene_path: String = "res://world_dream.tscn"
@export var reality_scene_path: String = "res://world_reality.tscn"
@export var return_scene_path: String = "res://node_2d.tscn"

@export var switch_duration: float = 0.2
@export var option_spacing: float = 320.0
@export var option_width: float = 360.0
@export var option_height: float = 240.0
@export var option_texture_height: float = 185.0

const OPTION_NAMES := ["room", "island", "forest", "dream", "reality", "continue"]

var _selected_index := 0
var _esc_confirm_pending := false
var _switch_tween: Tween
var _world_scene_paths: Array[String] = []
var _option_texture_paths: Array[String] = []
var _option_nodes: Array[Control] = []

@onready var _background: TextureRect = $Background
@onready var _track: Control = $OptionsTrack
@onready var _hint_label: Label = $HintLabel

func _ready() -> void:
	_world_scene_paths = [
		room_scene_path,
		island_scene_path,
		forest_scene_path,
		dream_scene_path,
		reality_scene_path,
		""
	]
	_option_texture_paths = [
		room_option_path,
		island_option_path,
		forest_option_path,
		dream_option_path,
		reality_option_path,
		continue_option_path
	]
	_option_nodes = [
		$OptionsTrack/OptionRoom,
		$OptionsTrack/OptionIsland,
		$OptionsTrack/OptionForest,
		$OptionsTrack/OptionDream,
		$OptionsTrack/OptionReality,
		$OptionsTrack/OptionContinue
	]

	_setup_background()
	_setup_options()
	_update_layout()
	_refresh_selection(true)

func _input(event: InputEvent) -> void:
	if EscExitHelper.handle_input(
		event,
		_esc_confirm_pending,
		return_scene_path,
		get_tree(),
		_set_esc_confirm_pending,
		Callable(),
		self
	):
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_A:
				_move_selection(-1)
				return
			KEY_D:
				_move_selection(1)
				return
			KEY_ENTER, KEY_KP_ENTER:
				_enter_selected_world()
				return

func _set_esc_confirm_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_refresh_selection(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if not is_node_ready():
			return
		_update_layout()
		_refresh_selection(true)

func _setup_background() -> void:
	_background.texture = _load_texture(sky_background_path)

func _setup_options() -> void:
	for i in range(_option_nodes.size()):
		var option := _option_nodes[i]
		var texture_rect := option.get_node("Texture") as TextureRect
		var label := option.get_node("Label") as Label

		option.clip_contents = true
		option.mouse_filter = Control.MOUSE_FILTER_IGNORE
		option.modulate = Color(1, 1, 1, 1)

		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.texture = _load_texture(_option_texture_paths[i])

		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = OPTION_NAMES[i]

func _move_selection(delta: int) -> void:
	var next_index := clampi(_selected_index + delta, 0, _option_nodes.size() - 1)
	if next_index == _selected_index:
		return

	_selected_index = next_index
	_esc_confirm_pending = false
	_refresh_selection(false)

func _refresh_selection(immediate: bool) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.56)
	var track_target_x := center.x - (_selected_index * option_spacing)
	var track_target := Vector2(track_target_x, center.y)

	if _switch_tween != null:
		_switch_tween.kill()

	if immediate:
		_track.position = track_target
	else:
		_switch_tween = create_tween()
		_switch_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_switch_tween.tween_property(_track, "position", track_target, switch_duration)

	for i in range(_option_nodes.size()):
		var option := _option_nodes[i]
		var target_scale := Vector2.ONE * (1.12 if i == _selected_index else 0.9)
		var target_alpha := 1.0 if i == _selected_index else 0.55

		if immediate:
			option.scale = target_scale
			option.modulate.a = target_alpha
		else:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(option, "scale", target_scale, switch_duration)
			tween.parallel().tween_property(option, "modulate:a", target_alpha, switch_duration)

	if _selected_index == _option_nodes.size() - 1:
		_hint_label.text = EscExitHelper.hint_text(
			_esc_confirm_pending,
			"A / D 切换 | continue 不可进入 | Esc 返回",
			"再按 Enter 确认返回主房间"
		)
	else:
		_hint_label.text = EscExitHelper.hint_text(
			_esc_confirm_pending,
			"A / D 切换 | Enter 进入 " + OPTION_NAMES[_selected_index] + "  |  Esc 返回",
			"再按 Enter 确认返回主房间"
		)

func _update_layout() -> void:
	var option_size := Vector2(option_width, option_height)
	for i in range(_option_nodes.size()):
		var option := _option_nodes[i]
		var texture_rect := option.get_node("Texture") as TextureRect
		var label := option.get_node("Label") as Label

		option.size = option_size
		option.position = Vector2(i * option_spacing - option_size.x * 0.5, -option_size.y * 0.5)
		option.pivot_offset = option_size * 0.5
		texture_rect.position = Vector2(0, 0)
		texture_rect.size = Vector2(option_size.x, option_texture_height)
		label.position = Vector2(0, option_texture_height + 6.0)
		label.size = Vector2(option_size.x, option_size.y - option_texture_height - 6.0)

	_hint_label.position = Vector2(size.x * 0.5 - 240, size.y * 0.88)

func _enter_selected_world() -> void:
	var target_scene := _world_scene_paths[_selected_index]
	if target_scene.is_empty():
		return
	get_tree().change_scene_to_file(target_scene)

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return load(path) as Texture2D
