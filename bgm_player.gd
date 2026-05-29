extends Node

const PATHS := {
	"firstpage": "res://Audio/ViccyC - Kamasutra（纯音乐）firstpage.mp3",
	"main": "res://Audio/ViccyC - Kamasutra（纯音乐）firstpage.mp3",
	"island": "res://Audio/Henry Jackman - For Better or Worses island.mp3",
	"forest": "res://Audio/Zak Gott - Forest.mp3",
	"room": "res://Audio/Stafford Bawler - The Garden room.mp3",
}
const SETTINGS_PATH := "user://settings.cfg"

var _player: AudioStreamPlayer
var _current_path: String = ""
var _volume_linear: float = 1.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)
	_load_settings()
	_apply_volume()


func play(key: String) -> void:
	var path: String = PATHS.get(key, "")
	if path.is_empty():
		return
	if path == _current_path and _player.playing:
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("BGM not found: %s" % path)
		return

	_set_loop(stream)
	_player.stream = stream
	_apply_volume()
	_player.play()
	_current_path = path


func stop() -> void:
	_player.stop()
	_current_path = ""


func get_volume_linear() -> float:
	return _volume_linear


func set_volume_linear(linear: float) -> void:
	_volume_linear = clampf(linear, 0.0, 1.0)
	_apply_volume()
	_save_settings()


func _apply_volume() -> void:
	if _player == null:
		return
	if _volume_linear <= 0.0:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(_volume_linear)


func _load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_volume_linear = float(cfg.get_value("audio", "bgm_volume", 1.0))
	_volume_linear = clampf(_volume_linear, 0.0, 1.0)


func _save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "bgm_volume", _volume_linear)
	cfg.save(SETTINGS_PATH)


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
