extends Control

const EscExitHelper = preload("res://esc_exit_helper.gd")
const ENTRY_COUNT: int = 2
const ENTRY_DIARY: int = 0
const ENTRY_TREASURE: int = 1
const VIEWER_NONE: int = 0
const VIEWER_DIARY: int = 1
const VIEWER_TREASURE: int = 2
const TREASURE_ENTRY_TEXT: String = """祖父的宝藏已经找到。

木箱里装着他的旅行手账、珍藏种子和写给暮秋的信。
这些不是金银，而是勇气与远方。"""

@export var return_scene_path: String = "res://node_2d.tscn"
@export var diary_texture_path: String = "res://Sprite/diary.png"
@export var diary_locked_texture_path: String = "res://Sprite/diary马赛克版.png"
@export var treasure_texture_path: String = "res://Sprite/宝藏.png"
@export var treasure_locked_texture_path: String = "res://Sprite/diary马赛克版.png"
@export var font_path: String = "res://HYPixel11pxU-2.ttf"

@onready var _diary_card: TextureRect = $DiaryCard
@onready var _treasure_card: TextureRect = $TreasureCard
@onready var _status_label: Label = $StatusLabel
@onready var _treasure_status_label: Label = $TreasureStatusLabel
@onready var _hint_label: Label = $HintLabel
@onready var _viewer: Control = $DiaryViewer
@onready var _viewer_image: TextureRect = $DiaryViewer/DiaryImage
@onready var _viewer_text: Label = $DiaryViewer/PagePanel/PageText
@onready var _viewer_hint: Label = $DiaryViewer/PageHint

var _diary_unlocked: bool = false
var _treasure_unlocked: bool = false
var _viewer_open: bool = false
var _viewer_mode: int = VIEWER_NONE
var _selected_entry: int = ENTRY_DIARY
var _page_index: int = 0
var _esc_confirm_pending: bool = false
var _quick_return_enabled: bool = false
var _quick_return_scene_path: String = ""


func _ready() -> void:
	BgmPlayer.play("firstpage")
	_setup_return_mode()
	_apply_font()
	_refresh_diary_state()
	_refresh_selection_visual()
	_viewer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _viewer_open:
		_handle_viewer_input(event)
		return

	if _quick_return_enabled and event.is_action_pressed("ui_cancel"):
		_return_to_quick_scene()
		_mark_input_handled()
		return

	if EscExitHelper.handle_input(
		event,
		_esc_confirm_pending,
		return_scene_path,
		get_tree(),
		_set_esc_pending,
		Callable(),
		self
	):
		return

	_handle_selection_input(event)


func _gui_input(event: InputEvent) -> void:
	if _viewer_open:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var diary_hit: bool = _diary_card.get_global_rect().has_point(mouse_event.global_position)
			var treasure_hit: bool = _treasure_card.get_global_rect().has_point(mouse_event.global_position)
			if diary_hit:
				_selected_entry = ENTRY_DIARY
				_refresh_selection_visual()
				_open_selected_entry()
			elif treasure_hit:
				_selected_entry = ENTRY_TREASURE
				_refresh_selection_visual()
				_open_selected_entry()


func _handle_viewer_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_viewer()
		_mark_input_handled()
		return

	if _viewer_mode != VIEWER_DIARY:
		return

	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_A:
		_page_index = maxi(0, _page_index - 1)
		_refresh_page()
		_mark_input_handled()
	elif key_event.keycode == KEY_D:
		_page_index = mini(CodexData.DIARY_PAGES.size() - 1, _page_index + 1)
		_refresh_page()
		_mark_input_handled()


func _open_diary() -> void:
	_viewer_mode = VIEWER_DIARY
	_viewer_open = true
	_page_index = 0
	_viewer_image.texture = load(diary_texture_path) as Texture2D
	_viewer.visible = true
	_refresh_page()
	_hint_label.visible = false


func _open_treasure() -> void:
	_viewer_mode = VIEWER_TREASURE
	_viewer_open = true
	_viewer.visible = true
	_viewer_image.texture = load(treasure_texture_path) as Texture2D
	_viewer_text.text = TREASURE_ENTRY_TEXT
	_viewer_hint.text = "Esc 关闭"
	_hint_label.visible = false


func _close_viewer() -> void:
	_viewer_mode = VIEWER_NONE
	_viewer_open = false
	_viewer.visible = false
	_hint_label.visible = true


func _refresh_page() -> void:
	var page_text: String = CodexData.DIARY_PAGES[_page_index]
	_viewer_text.text = page_text
	_viewer_hint.text = "A/D 翻页  |  Esc 关闭  |  %d/%d" % [_page_index + 1, CodexData.DIARY_PAGES.size()]


func _refresh_diary_state() -> void:
	_diary_unlocked = CodexState.is_diary_unlocked()
	_treasure_unlocked = CodexState.is_treasure_unlocked()
	if _diary_unlocked:
		_diary_card.texture = load(diary_texture_path) as Texture2D
		_status_label.text = "图鉴：日记（已解锁）"
	else:
		_diary_card.texture = load(diary_locked_texture_path) as Texture2D
		_status_label.text = "图鉴：日记（未解锁）"

	if _treasure_unlocked:
		_treasure_card.texture = load(treasure_texture_path) as Texture2D
		_treasure_status_label.text = "图鉴：宝藏（已解锁）"
	else:
		_treasure_card.texture = load(treasure_locked_texture_path) as Texture2D
		_treasure_status_label.text = "图鉴：宝藏（未解锁）"

	_hint_label.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		_build_idle_hint_text(),
		"再按 Enter 确认返回主场景"
	)

	_refresh_selection_visual()


func _set_esc_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_refresh_diary_state()


func _handle_selection_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
		_selected_entry = posmod(_selected_entry - 1, ENTRY_COUNT)
		_refresh_selection_visual()
		_mark_input_handled()
		return
	if key_event.keycode == KEY_D or key_event.keycode == KEY_RIGHT:
		_selected_entry = posmod(_selected_entry + 1, ENTRY_COUNT)
		_refresh_selection_visual()
		_mark_input_handled()
		return
	if EscExitHelper.is_enter_pressed(event):
		_open_selected_entry()
		_mark_input_handled()


func _open_selected_entry() -> void:
	if _selected_entry == ENTRY_DIARY:
		if _diary_unlocked:
			_open_diary()
		else:
			_status_label.text = "图鉴尚未解锁：日记（请先在书房完成抽屉任务）"
		return

	if _treasure_unlocked:
		_open_treasure()
	else:
		_treasure_status_label.text = "图鉴：宝藏（未解锁，需在岛屿世界拿到宝藏）"


func _build_idle_hint_text() -> String:
	var esc_text: String = "Esc 返回小岛" if _quick_return_enabled else "Esc 返回主场景"
	var action_text: String = ""
	if _selected_entry == ENTRY_DIARY:
		action_text = "Enter 进入日记" if _diary_unlocked else "日记未解锁"
	else:
		action_text = "Enter 进入宝藏" if _treasure_unlocked else "宝藏未解锁"
	return "A/D 切换图鉴  |  %s  |  %s" % [action_text, esc_text]


func _refresh_selection_visual() -> void:
	var diary_selected: bool = _selected_entry == ENTRY_DIARY
	var treasure_selected: bool = _selected_entry == ENTRY_TREASURE
	_diary_card.scale = Vector2.ONE * (1.04 if diary_selected else 0.94)
	_treasure_card.scale = Vector2.ONE * (1.04 if treasure_selected else 0.94)
	_diary_card.modulate = Color(1, 1, 1, 1.0 if diary_selected else 0.72)
	_treasure_card.modulate = Color(1, 1, 1, 1.0 if treasure_selected else 0.72)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6, 1.0) if diary_selected else Color(0.9, 0.88, 0.82, 1.0))
	_treasure_status_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6, 1.0) if treasure_selected else Color(0.9, 0.88, 0.82, 1.0))
	_hint_label.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		_build_idle_hint_text(),
		"再按 Enter 确认返回主场景"
	)


func _setup_return_mode() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_quick_return_enabled = bool(tree.get_meta("codex_quick_return", false))
	_quick_return_scene_path = str(tree.get_meta("codex_return_scene_path", ""))
	tree.remove_meta("codex_quick_return")
	tree.remove_meta("codex_return_scene_path")


func _return_to_quick_scene() -> void:
	if _quick_return_scene_path.is_empty():
		_quick_return_scene_path = "res://world_island.tscn"
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.set_meta("skip_intro_once_scene", _quick_return_scene_path)
	get_tree().change_scene_to_file(_quick_return_scene_path)


func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _apply_font() -> void:
	var font: FontFile = load(font_path) as FontFile
	if font == null:
		return
	for label: Label in [_status_label, _treasure_status_label, _hint_label, _viewer_text, _viewer_hint]:
		label.add_theme_font_override("font", font)
