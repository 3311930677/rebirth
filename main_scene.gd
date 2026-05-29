extends Node2D

const EscExitHelper = preload("res://esc_exit_helper.gd")

# 设置图标位置：场景树选中 DoorSigns/SettingsSign，改 Position 和 Scale。
@export_group("settings")
@export var settings_trigger_distance: float = 120.0

@onready var _player: CharacterBody2D = $Player
@onready var _settings_sign: Node2D = $DoorSigns/SettingsSign
@onready var _settings_menu: SettingsMenuPanel = $UI/SettingsMenu
@onready var _settings_hint: Label = $UI/SettingsHint

var _near_settings := false


func _ready() -> void:
	BgmPlayer.play("firstpage")
	_settings_hint.visible = false
	_apply_settings_hint_font()


func _apply_settings_hint_font() -> void:
	var font: FontFile = load("res://HYPixel11pxU-2.ttf") as FontFile
	if font != null:
		_settings_hint.add_theme_font_override("font", font)


func _process(_delta: float) -> void:
	if _settings_menu.visible:
		_settings_hint.visible = false
		return
	_near_settings = (
		_player.global_position.distance_to(_settings_sign.global_position)
		<= settings_trigger_distance
	)
	_settings_hint.visible = _near_settings


func _unhandled_input(event: InputEvent) -> void:
	if _settings_menu.visible:
		return
	if not _near_settings:
		return
	if EscExitHelper.is_enter_pressed(event):
		_settings_menu.open(_player)
		get_viewport().set_input_as_handled()
