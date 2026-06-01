extends Node2D

const EscExitHelper = preload("res://esc_exit_helper.gd")

# 设置图标位置：场景树选中 DoorSigns/SettingsSign，改 Position 和 Scale。
@export_group("settings")
@export var settings_trigger_distance: float = 120.0
@export_group("inaba_ciallo")
@export var inaba_trigger_distance: float = 150.0
@export var inaba_texture_path: String = "res://Sprite/inaba.png"
@export var ciallo_audio_path: String = "res://Audio/ciallo.mp3"
@export var ciallo_audio_dir: String = "res://Audio"
@export var ciallo_audio_keyword: String = "ciallo"

@onready var _player: CharacterBody2D = $Player
@onready var _settings_sign: Node2D = $DoorSigns/SettingsSign
@onready var _inaba_sign: Sprite2D = $DoorSigns/InabaSign
@onready var _settings_menu: SettingsMenuPanel = $UI/SettingsMenu
@onready var _settings_hint: Label = $UI/SettingsHint

var _near_settings := false
var _near_inaba := false
var _was_near_inaba := false
var _ciallo_player: AudioStreamPlayer = null
var _ciallo_stream: AudioStream = null


func _ready() -> void:
	BgmPlayer.play("firstpage")
	_settings_hint.visible = false
	_apply_settings_hint_font()
	_setup_inaba_sign()
	_setup_ciallo_player()


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
	_near_inaba = (
		_inaba_sign != null
		and _player.global_position.distance_to(_inaba_sign.global_position) <= inaba_trigger_distance
	)
	if _near_inaba and not _was_near_inaba:
		_play_ciallo()
	_was_near_inaba = _near_inaba
	_settings_hint.visible = _near_settings


func _unhandled_input(event: InputEvent) -> void:
	if _settings_menu.visible:
		return
	if not _near_settings:
		return
	if EscExitHelper.is_enter_pressed(event):
		_settings_menu.open(_player)
		get_viewport().set_input_as_handled()


func _setup_inaba_sign() -> void:
	if _inaba_sign == null:
		return
	if _inaba_sign.texture != null:
		return
	var tex: Texture2D = load(inaba_texture_path) as Texture2D
	if tex != null:
		_inaba_sign.texture = tex


func _setup_ciallo_player() -> void:
	_ciallo_player = AudioStreamPlayer.new()
	_ciallo_player.name = "CialloPlayer"
	add_child(_ciallo_player)


func _play_ciallo() -> void:
	if _ciallo_player == null:
		return
	if _ciallo_stream == null:
		_ciallo_stream = _resolve_ciallo_stream()
	if _ciallo_stream == null:
		return
	_ciallo_player.stream = _ciallo_stream
	_ciallo_player.play()


func _resolve_ciallo_stream() -> AudioStream:
	if not ciallo_audio_path.is_empty():
		var direct_stream: AudioStream = load(ciallo_audio_path) as AudioStream
		if direct_stream != null:
			return direct_stream

	var dir: DirAccess = DirAccess.open(ciallo_audio_dir)
	if dir == null:
		return null
	for raw_name in dir.get_files():
		var file_name: String = str(raw_name)
		var lower_name: String = file_name.to_lower()
		if (
			lower_name.contains(ciallo_audio_keyword.to_lower())
			and (lower_name.ends_with(".mp3") or lower_name.ends_with(".ogg") or lower_name.ends_with(".wav"))
		):
			var stream_path: String = ciallo_audio_dir.path_join(file_name)
			var stream: AudioStream = load(stream_path) as AudioStream
			if stream != null:
				return stream
	return null
