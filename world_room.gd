extends "res://world_page.gd"

@export var font_path: String = "res://HYPixel11pxU-2.ttf"
@export var player_spawn_uv: Vector2 = Vector2(0.50, 0.72)

const ROOM_OPENING_DURATION := 8.0
const ROOM_OPENING_TEXT := """祖父离世一周年，暮秋推开尘封的书房门。煤油灯亮起，桌上旧钥匙压着便签：
"这世界是一个谜" """

const INSPECT_IMAGE_BASE_SIZE := Vector2(640.0, 480.0)
const INSPECT_IMAGE_Y_OFFSET := 40.0

const INSPECT_ITEMS: Array[Dictionary] = [
	{
		"id": "painting",
		"trigger_path": NodePath("MapBackground/PaintingTrigger"),
		"image_path": "res://Sprite/painting.png",
		"preview_text": "点击图片查看线索",
		"clue_text": "【线索】二木并立，相依而生；清风过处，叶语沙沙。",
		"image_display_scale": 1.0,
	},
	{
		"id": "globe",
		"trigger_path": NodePath("MapBackground/GlobeTrigger"),
		"image_path": "res://Sprite/地球仪.png",
		"preview_text": "点击图片查看线索",
		"clue_text": "【线索】踏遍五洲浪，最念故园青。层峦叠嶂之奇秀，盘桓蜿蜒之亘古。",
		"image_display_scale": 0.58,
	},
	{
		"id": "telescope",
		"trigger_path": NodePath("MapBackground/TelescopeTrigger"),
		"image_path": "res://Sprite/望远镜.png",
		"preview_text": "点击图片查看线索",
		"clue_text": "【线索】我穷尽一生，只为带你看清山海尽头，遥遥难及。",
		"image_display_scale": 0.58,
	},
	{
		"id": "key",
		"trigger_path": NodePath("MapBackground/KeyTrigger"),
		"image_path": "res://Sprite/钥匙.png",
		"preview_text": "点击图片查看线索",
		"clue_text": "【线索】钥匙不仅可以打开盒子，还可以打开书房右下角的暗门，但是里面一片漆黑，什么也没有，也许一片漆黑本身也是个线索？",
		"image_display_scale": 0.52,
	},
	{
		"id": "drawer",
		"trigger_path": NodePath("MapBackground/DrawerTrigger"),
		"image_path": "res://Sprite/diary.png",
		"preview_text": "点击图片打开抽屉",
		"clue_text": "",
		"image_display_scale": 0.68,
	},
]

@onready var _inspect_view: Control = $UI/PaintingView
@onready var _dialogue_panel: Panel = $UI/PaintingView/DialoguePanel
@onready var _dialogue_label: Label = $UI/PaintingView/DialoguePanel/DialogueLabel
@onready var _inspect_image: TextureRect = $UI/PaintingView/PaintingImage
@onready var _inspect_hint: Label = $UI/PaintingView/CloseHint
@onready var _opening_view: Control = $UI/OpeningView
@onready var _opening_label: Label = $UI/OpeningView/OpeningLabel
@onready var _diary_view: Control = $UI/DiaryView
@onready var _diary_text: Label = $UI/DiaryView/PagePanel/PageText
@onready var _diary_hint: Label = $UI/DiaryView/PageHint
@onready var _unlock_hint: Label = $UI/DiaryView/UnlockHint

var _inspect_items: Array[Dictionary] = []
var _inspect_open: bool = false
var _active_item: Dictionary = {}
var _diary_open: bool = false
var _diary_page_index: int = 0
var _opening_started: bool = false
var _opening_elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	_build_inspect_items()
	_setup_ui()
	_place_player_at_spawn()
	if _player != null:
		_player.refresh_movement_bounds()
	_restore_world_progress()


func _process(delta: float) -> void:
	super._process(delta)
	_update_room_opening(delta)


func _build_inspect_items() -> void:
	_inspect_items.clear()
	for item_config in INSPECT_ITEMS:
		var item: Dictionary = item_config.duplicate(true) as Dictionary
		var trigger: Area2D = get_node_or_null(item["trigger_path"]) as Area2D
		if trigger == null:
			continue
		var shape: CollisionShape2D = trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null:
			continue
		item["trigger"] = trigger
		item["shape"] = shape
		item["was_in_zone"] = false
		item["clue_revealed"] = false
		trigger.monitoring = true
		trigger.monitorable = false
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		_inspect_items.append(item)


func _setup_ui() -> void:
	var font: FontFile = load(font_path) as FontFile
	if font != null:
		for label in [_dialogue_label, _inspect_hint, _opening_label, _diary_text, _diary_hint, _unlock_hint]:
			label.add_theme_font_override("font", font)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.9)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 8
	_dialogue_panel.add_theme_stylebox_override("panel", panel_style)

	_dialogue_label.add_theme_font_size_override("font_size", 22)
	_dialogue_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))
	_inspect_hint.text = "Esc 退出查看"
	_inspect_view.visible = false
	_opening_label.text = ROOM_OPENING_TEXT
	_opening_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opening_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_opening_view.visible = false
	_diary_view.visible = false
	_unlock_hint.visible = false
	_unlock_hint.text = "解锁图鉴：日记"


func _place_player_at_center() -> void:
	_place_player_at_spawn()


func _place_player_at_spawn() -> void:
	if _player == null or _background.texture == null:
		return
	var tex_size: Vector2 = _background.texture.get_size()
	var offset: Vector2 = (player_spawn_uv - Vector2(0.5, 0.5)) * tex_size * _background.scale
	_player.global_position = _background.global_position + offset


func _on_viewport_size_changed() -> void:
	super._on_viewport_size_changed()
	_place_player_at_spawn()
	if _player != null:
		_player.refresh_movement_bounds()


func _input(event: InputEvent) -> void:
	if _diary_open:
		_handle_diary_input(event)
		return

	if _inspect_open:
		if event.is_action_pressed("ui_cancel"):
			_close_inspect_view()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_inspect_image_clicked()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _inspect_open or _diary_open or _is_room_opening_active():
		return
	super._unhandled_input(event)


func _physics_process(_delta: float) -> void:
	if _inspect_open or _diary_open or is_intro_video_playing() or _is_room_opening_active() or _player == null:
		return

	for item in _inspect_items:
		var in_zone: bool = _is_player_in_zone(item)
		if in_zone and not item["was_in_zone"]:
			_open_inspect_view(item)
		item["was_in_zone"] = in_zone


func _is_player_in_zone(item: Dictionary) -> bool:
	var shape: CollisionShape2D = item["shape"] as CollisionShape2D
	if shape.shape is not RectangleShape2D:
		return false
	var rect_shape: RectangleShape2D = shape.shape as RectangleShape2D
	var shape_scale: Vector2 = shape.global_transform.get_scale()
	var size: Vector2 = Vector2(
		rect_shape.size.x * absf(shape_scale.x),
		rect_shape.size.y * absf(shape_scale.y)
	)
	var center: Vector2 = shape.global_position
	var zone_rect := Rect2(center - size * 0.5, size)
	var player_half: Vector2 = _player.get_collision_half_extents()
	var player_rect := Rect2(_player.global_position - player_half, player_half * 2.0)
	return zone_rect.intersects(player_rect)


func _apply_inspect_image_layout(display_scale: float) -> void:
	var size: Vector2 = INSPECT_IMAGE_BASE_SIZE * display_scale
	var half: Vector2 = size * 0.5
	var center_y: float = INSPECT_IMAGE_Y_OFFSET
	_inspect_image.offset_left = -half.x
	_inspect_image.offset_right = half.x
	_inspect_image.offset_top = center_y - half.y
	_inspect_image.offset_bottom = center_y + half.y


func _open_inspect_view(item: Dictionary) -> void:
	if _inspect_open:
		return
	_active_item = item
	_inspect_open = true
	_inspect_image.texture = load(item["image_path"] as String) as Texture2D
	_apply_inspect_image_layout(item.get("image_display_scale", 1.0) as float)
	_apply_normal_dialogue_style()
	_dialogue_label.text = item["preview_text"] as String
	_inspect_view.visible = true
	_hint.visible = false
	_release_player_control()


func _on_inspect_image_clicked() -> void:
	if _active_item.is_empty():
		return
	var item_id: String = _active_item.get("id", "") as String
	if item_id == "drawer":
		_open_diary_from_drawer()
		return
	# 线索允许重复点击查看，不做一次性限制。
	_active_item["clue_revealed"] = true
	_apply_clue_dialogue_style()
	_dialogue_label.text = _active_item["clue_text"] as String


func _close_inspect_view() -> void:
	_inspect_open = false
	_inspect_view.visible = false
	_hint.visible = true
	if not _active_item.is_empty():
		_active_item["was_in_zone"] = _is_player_in_zone(_active_item)
	_active_item = {}
	_release_player_control()


func _open_diary_from_drawer() -> void:
	_inspect_open = false
	_inspect_view.visible = false
	_diary_open = true
	_diary_page_index = 0
	_diary_text.text = CodexData.DIARY_PAGES[_diary_page_index]
	_update_diary_hint()
	_diary_view.visible = true
	_unlock_hint.visible = true
	_hint.visible = false
	CodexState.unlock_diary()
	_release_player_control()


func _close_diary() -> void:
	_diary_open = false
	_diary_view.visible = false
	_unlock_hint.visible = false
	_hint.visible = true
	_release_player_control()


func _handle_diary_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_diary()
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_A:
		_diary_page_index = maxi(0, _diary_page_index - 1)
		_diary_text.text = CodexData.DIARY_PAGES[_diary_page_index]
		_update_diary_hint()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_D:
		_diary_page_index = mini(CodexData.DIARY_PAGES.size() - 1, _diary_page_index + 1)
		_diary_text.text = CodexData.DIARY_PAGES[_diary_page_index]
		_update_diary_hint()
		get_viewport().set_input_as_handled()


func _update_diary_hint() -> void:
	_diary_hint.text = "A/D 翻页  |  Esc 关闭  |  %d/%d" % [_diary_page_index + 1, CodexData.DIARY_PAGES.size()]


func _apply_normal_dialogue_style() -> void:
	_dialogue_label.add_theme_font_size_override("font_size", 22)
	_dialogue_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))


func _apply_clue_dialogue_style() -> void:
	_dialogue_label.add_theme_font_size_override("font_size", 24)
	_dialogue_label.add_theme_color_override("font_color", Color(1, 0.86, 0.35, 1))


func _update_room_opening(delta: float) -> void:
	if _opening_started:
		_opening_elapsed += delta
		if _opening_elapsed >= ROOM_OPENING_DURATION:
			_opening_started = false
			_opening_view.visible = false
			_hint.visible = true
			_release_player_control()
		return

	if is_intro_video_playing():
		return

	if _opening_elapsed > 0.0:
		return

	_opening_started = true
	_opening_elapsed = 0.001
	_opening_view.visible = true
	_hint.visible = false
	_release_player_control()


func _is_room_opening_active() -> bool:
	return _opening_started


func _release_player_control() -> void:
	if _player == null:
		return
	var locked: bool = (
		_inspect_open
		or _diary_open
		or _is_room_opening_active()
		or is_intro_video_playing()
	)
	_player.set_physics_process(not locked)
