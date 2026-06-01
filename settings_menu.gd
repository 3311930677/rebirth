extends CanvasLayer

class_name SettingsMenuPanel

signal closed

enum Page { MAIN, VOLUME, GUIDE, CREDITS }

const EscExitHelper = preload("res://esc_exit_helper.gd")
const FONT_PATH := "res://HYPixel11pxU-2.ttf"

const MENU_OPTIONS: Array[String] = [
	"背景音乐音量",
	"玩法说明",
	"支持我们",
]

const GUIDE_TEXT := """使用 WASD 控制角色移动。

主场景
  · 靠近 begin 并移动 → 进入世界选择
  · 靠近任务板并移动 → 查看每日任务
  · 靠近设置图标，按 Enter → 打开设置

世界场景
  · 按 Esc 可稳定呼出返回确认，再按 Enter 返回世界选择
  · 靠近特定物品可触发查看与对话

forest 场景战斗
  · 左键点击即可发射一发光球（无射速上限）
  · 空格触发更高、滞空更久的跳跃
  · 左键朝向鼠标位置开火，适合边走位边输出

提示：设置中的音量会应用到所有场景。"""

const CREDITS_TEXT := """开发人员

  谈世钊
  主策划 · 文案 · 代码编辑

  刘力瑞
  美术 · 代码测试

联系邮箱
  3311930677@qq.com

开源仓库
  https://github.com/3311930677/rebirth/tree/master

特别鸣谢
  godot引擎 · z4919 · 落木逐风"""

const COLOR_TITLE := Color(1, 0.96, 0.86, 1)
const COLOR_BODY := Color(0.92, 0.88, 0.8, 1)
const COLOR_HINT := Color(0.7, 0.66, 0.58, 1)
const COLOR_SELECTED := Color(1, 0.9, 0.45, 1)
const COLOR_NORMAL := Color(0.75, 0.71, 0.64, 1)

@onready var _panel: Panel = $Root/Panel
@onready var _title: Label = $Root/Panel/Margin/VBox/TitleLabel
@onready var _body: Control = $Root/Panel/Margin/VBox/Body
@onready var _main_list: VBoxContainer = $Root/Panel/Margin/VBox/Body/MainList
@onready var _scroll: ScrollContainer = $Root/Panel/Margin/VBox/Body/Scroll
@onready var _scroll_label: Label = $Root/Panel/Margin/VBox/Body/Scroll/ScrollLabel
@onready var _volume_box: VBoxContainer = $Root/Panel/Margin/VBox/Body/VolumeBox
@onready var _volume_desc: Label = $Root/Panel/Margin/VBox/Body/VolumeBox/VolumeDesc
@onready var _volume_slider: HSlider = $Root/Panel/Margin/VBox/Body/VolumeBox/VolumeRow/VolumeSlider
@onready var _volume_value: Label = $Root/Panel/Margin/VBox/Body/VolumeBox/VolumeRow/VolumeValueLabel
@onready var _hint: Label = $Root/Panel/Margin/VBox/HintLabel

var _option_labels: Array[Label] = []
var _page: Page = Page.MAIN
var _main_index: int = 0
var _player: CharacterBody2D = null


func _ready() -> void:
	visible = false
	_option_labels = [
		_main_list.get_node("Option0") as Label,
		_main_list.get_node("Option1") as Label,
		_main_list.get_node("Option2") as Label,
	]
	_apply_font()
	_apply_panel_style()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	_refresh()


func open(player: CharacterBody2D = null) -> void:
	_player = player
	if _player != null:
		_player.set_physics_process(false)
	_page = Page.MAIN
	_main_index = 0
	_volume_slider.value = BgmPlayer.get_volume_linear() * 100.0
	_scroll.scroll_vertical = 0
	visible = true
	_refresh()


func close() -> void:
	if _player != null:
		_player.set_physics_process(true)
		_player = null
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if _page == Page.MAIN:
			close()
		else:
			_page = Page.MAIN
			_scroll.scroll_vertical = 0
			_refresh()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return

	match _page:
		Page.MAIN:
			_handle_main_input(event)
		Page.VOLUME:
			_handle_volume_input(event)


func _handle_main_input(event: InputEvent) -> void:
	if EscExitHelper.is_enter_pressed(event):
		match _main_index:
			0:
				_page = Page.VOLUME
			1:
				_page = Page.GUIDE
			2:
				_page = Page.CREDITS
		_scroll.scroll_vertical = 0
		_refresh()
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_W):
		_main_index = (_main_index - 1 + MENU_OPTIONS.size()) % MENU_OPTIONS.size()
		_refresh()
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_S):
		_main_index = (_main_index + 1) % MENU_OPTIONS.size()
		_refresh()
		get_viewport().set_input_as_handled()


func _handle_volume_input(event: InputEvent) -> void:
	if _is_key(event, KEY_A):
		_volume_slider.value = maxf(_volume_slider.min_value, _volume_slider.value - 5.0)
		get_viewport().set_input_as_handled()
	elif _is_key(event, KEY_D):
		_volume_slider.value = minf(_volume_slider.max_value, _volume_slider.value + 5.0)
		get_viewport().set_input_as_handled()


func _is_key(event: InputEvent, keycode: Key) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == keycode


func _on_volume_changed(value: float) -> void:
	BgmPlayer.set_volume_linear(value / 100.0)
	_volume_value.text = "%d%%" % int(round(value))


func _refresh() -> void:
	_hide_all_bodies()

	match _page:
		Page.MAIN:
			_title.text = "—  设置  —"
			_main_list.visible = true
			_refresh_main_options()
			_hint.text = "W / S 选择选项    Enter 确认    Esc 关闭"
		Page.VOLUME:
			_title.text = "—  背景音乐  —"
			_volume_box.visible = true
			_volume_value.text = "%d%%" % int(round(_volume_slider.value))
			_hint.text = "A / D 微调音量    可拖动滑块    Esc 返回"
		Page.GUIDE:
			_title.text = "—  玩法说明  —"
			_scroll.visible = true
			_scroll_label.text = GUIDE_TEXT
			_fit_scroll_label()
			_hint.text = "Esc 返回上一级"
		Page.CREDITS:
			_title.text = "—  支持我们  —"
			_scroll.visible = true
			_scroll_label.text = CREDITS_TEXT
			_fit_scroll_label()
			_hint.text = "Esc 返回上一级"


func _hide_all_bodies() -> void:
	_main_list.visible = false
	_scroll.visible = false
	_volume_box.visible = false


func _refresh_main_options() -> void:
	for i in range(_option_labels.size()):
		var label: Label = _option_labels[i]
		var selected: bool = i == _main_index
		if selected:
			label.text = "▶  %s" % MENU_OPTIONS[i]
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			label.text = "     %s" % MENU_OPTIONS[i]
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", COLOR_NORMAL)


func _fit_scroll_label() -> void:
	var width: float = maxf(_scroll.size.x - 8.0, 720.0)
	_scroll_label.custom_minimum_size = Vector2(width, 0.0)
	await get_tree().process_frame
	_scroll_label.custom_minimum_size = Vector2(width, _scroll_label.get_minimum_size().y)


func _apply_font() -> void:
	var font: FontFile = load(FONT_PATH) as FontFile
	if font == null:
		return

	var nodes: Array[Label] = [
		_title, _scroll_label, _volume_desc, _volume_value, _hint
	]
	nodes.append_array(_option_labels)
	for node: Label in nodes:
		node.add_theme_font_override("font", font)


func _apply_panel_style() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.055, 0.09, 0.96)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 4
	panel_style.content_margin_top = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_bottom = 4
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.62, 0.52, 0.36, 1)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", panel_style)

	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", COLOR_TITLE)
	_scroll_label.add_theme_font_size_override("font_size", 18)
	_scroll_label.add_theme_color_override("font_color", COLOR_BODY)
	_volume_desc.add_theme_font_size_override("font_size", 20)
	_volume_desc.add_theme_color_override("font_color", COLOR_BODY)
	_volume_value.add_theme_font_size_override("font_size", 22)
	_volume_value.add_theme_color_override("font_color", COLOR_TITLE)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", COLOR_HINT)

	for label: Label in _option_labels:
		label.add_theme_constant_override("outline_size", 0)
