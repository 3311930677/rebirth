extends Control

const EscExitHelper = preload("res://esc_exit_helper.gd")

@export var return_scene_path: String = "res://node_2d.tscn"
@export var diary_texture_path: String = "res://Sprite/diary.png"
@export var diary_locked_texture_path: String = "res://Sprite/diary马赛克版.png"
@export var font_path: String = "res://HYPixel11pxU-2.ttf"

@onready var _diary_card: TextureRect = $DiaryCard
@onready var _status_label: Label = $StatusLabel
@onready var _hint_label: Label = $HintLabel
@onready var _viewer: Control = $DiaryViewer
@onready var _viewer_text: Label = $DiaryViewer/PagePanel/PageText
@onready var _viewer_hint: Label = $DiaryViewer/PageHint

var _diary_unlocked: bool = false
var _viewer_open: bool = false
var _page_index: int = 0
var _esc_confirm_pending: bool = false


func _ready() -> void:
	BgmPlayer.play("firstpage")
	_apply_font()
	_refresh_diary_state()
	_viewer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _viewer_open:
		_handle_viewer_input(event)
		return

	if EscExitHelper.handle_input(
		event,
		_esc_confirm_pending,
		return_scene_path,
		get_tree(),
		_set_esc_pending
	):
		return

	if not EscExitHelper.is_enter_pressed(event):
		return

	if _diary_unlocked:
		_open_diary()
	else:
		_status_label.text = "图鉴尚未解锁：日记（请先在书房完成抽屉任务）"


func _gui_input(event: InputEvent) -> void:
	if _viewer_open:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _diary_unlocked:
				_open_diary()
			else:
				_status_label.text = "图鉴尚未解锁：日记（请先在书房完成抽屉任务）"


func _handle_viewer_input(event: InputEvent) -> void:
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
		_page_index = maxi(0, _page_index - 1)
		_refresh_page()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_D:
		_page_index = mini(CodexData.DIARY_PAGES.size() - 1, _page_index + 1)
		_refresh_page()
		get_viewport().set_input_as_handled()


func _open_diary() -> void:
	_viewer_open = true
	_page_index = 0
	_viewer.visible = true
	_refresh_page()
	_hint_label.visible = false


func _close_diary() -> void:
	_viewer_open = false
	_viewer.visible = false
	_hint_label.visible = true


func _refresh_page() -> void:
	var page_text: String = CodexData.DIARY_PAGES[_page_index]
	_viewer_text.text = page_text
	_viewer_hint.text = "A/D 翻页  |  Esc 关闭  |  %d/%d" % [_page_index + 1, CodexData.DIARY_PAGES.size()]


func _refresh_diary_state() -> void:
	_diary_unlocked = CodexState.is_diary_unlocked()
	if _diary_unlocked:
		_diary_card.texture = load(diary_texture_path) as Texture2D
		_status_label.text = "图鉴：日记（已解锁）"
		_hint_label.text = EscExitHelper.hint_text(
			_esc_confirm_pending,
			"Enter 打开日记  |  Esc 返回主场景",
			"再按 Enter 确认返回主场景"
		)
	else:
		_diary_card.texture = load(diary_locked_texture_path) as Texture2D
		_status_label.text = "图鉴：日记（未解锁）"
		_hint_label.text = EscExitHelper.hint_text(
			_esc_confirm_pending,
			"未解锁，暂不可打开  |  Esc 返回主场景",
			"再按 Enter 确认返回主场景"
		)


func _set_esc_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_refresh_diary_state()


func _apply_font() -> void:
	var font: FontFile = load(font_path) as FontFile
	if font == null:
		return
	for label: Label in [_status_label, _hint_label, _viewer_text, _viewer_hint]:
		label.add_theme_font_override("font", font)
