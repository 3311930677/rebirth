extends "res://world_page.gd"

@export var font_path: String = "res://HYPixel11pxU-2.ttf"
@export var player_spawn_uv: Vector2 = Vector2(0.50, 0.72)

const INSPECT_IMAGE_BASE_SIZE := Vector2(640.0, 480.0)
const INSPECT_IMAGE_Y_OFFSET := 40.0

const INSPECT_ITEMS: Array[Dictionary] = [
	{
		"trigger_path": NodePath("MapBackground/PaintingTrigger"),
		"image_path": "res://Sprite/painting.png",
		"dialogue": "让我看看这幅画有什么特别的..............",
		"image_display_scale": 1.0,
	},
	{
		"trigger_path": NodePath("MapBackground/GlobeTrigger"),
		"image_path": "res://Sprite/地球仪.png",
		"dialogue": "铜制的地球仪已经氧化发暗，上面的航线标记还清晰可见，仿佛在诉说过去的远洋冒险。",
		"image_display_scale": 0.58,
	},
	{
		"trigger_path": NodePath("MapBackground/TelescopeTrigger"),
		"image_path": "res://Sprite/望远镜.png",
		"dialogue": "这台望远镜蒙尘已久，镜筒上还刻着模糊的星图，望向窗外，好像能看见旧时光里的银河。",
		"image_display_scale": 0.58,
	},
	{
		"trigger_path": NodePath("MapBackground/KeyTrigger"),
		"image_path": "res://Sprite/钥匙.png",
		"dialogue": "一把造型别致的钥匙，不知道可以打开什么地方的门",
		"image_display_scale": 0.52,
	},
]

@onready var _inspect_view: Control = $UI/PaintingView
@onready var _dialogue_panel: Panel = $UI/PaintingView/DialoguePanel
@onready var _dialogue_label: Label = $UI/PaintingView/DialoguePanel/DialogueLabel
@onready var _inspect_image: TextureRect = $UI/PaintingView/PaintingImage
@onready var _inspect_hint: Label = $UI/PaintingView/CloseHint

var _inspect_items: Array[Dictionary] = []
var _inspect_open := false
var _active_item: Dictionary = {}

func _ready() -> void:
	_inspect_view.visible = false
	super._ready()
	_build_inspect_items()
	_setup_inspect_view()
	_place_player_at_spawn()
	if _player != null:
		_player.refresh_movement_bounds()

func _build_inspect_items() -> void:
	_inspect_items.clear()
	for item_config in INSPECT_ITEMS:
		var item: Dictionary = item_config.duplicate(true)
		var trigger: Area2D = get_node_or_null(item["trigger_path"]) as Area2D
		if trigger == null:
			continue
		var shape: CollisionShape2D = trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null:
			continue
		item["trigger"] = trigger
		item["shape"] = shape
		item["was_in_zone"] = false
		trigger.monitoring = true
		trigger.monitorable = false
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		if not trigger.body_entered.is_connected(_on_inspect_trigger_body_entered):
			trigger.body_entered.connect(_on_inspect_trigger_body_entered.bind(item))
		_inspect_items.append(item)

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
	if not _inspect_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_inspect_view()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _inspect_open:
		return
	super._unhandled_input(event)

func _setup_inspect_view() -> void:
	var font: FontFile = load(font_path) as FontFile
	if font != null:
		_dialogue_label.add_theme_font_override("font", font)
		_inspect_hint.add_theme_font_override("font", font)

	_dialogue_label.add_theme_font_size_override("font_size", 22)
	_dialogue_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.9)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 8
	_dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	_inspect_hint.text = "Esc 退出查看"
	_inspect_view.visible = false
	_inspect_open = false

func _physics_process(_delta: float) -> void:
	if _inspect_open or is_intro_video_playing() or _player == null:
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

func _on_inspect_trigger_body_entered(body: Node2D, item: Dictionary) -> void:
	if body != _player or _inspect_open or is_intro_video_playing():
		return
	_open_inspect_view(item)

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
	_dialogue_label.text = item["dialogue"] as String
	_inspect_image.texture = load(item["image_path"] as String) as Texture2D
	_apply_inspect_image_layout(item.get("image_display_scale", 1.0) as float)
	_inspect_view.visible = true
	_hint.visible = false
	if _player != null:
		_player.set_physics_process(false)

func _close_inspect_view() -> void:
	_inspect_open = false
	_inspect_view.visible = false
	_hint.visible = true
	if not _active_item.is_empty():
		_active_item["was_in_zone"] = _is_player_in_zone(_active_item)
	_active_item = {}
	if _player != null:
		_player.set_physics_process(true)
