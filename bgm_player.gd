extends Node

const PATHS := {
	"firstpage": "res://Audio/ViccyC - Kamasutra（纯音乐）firstpage.mp3",
	"main": "res://Audio/ViccyC - Kamasutra（纯音乐）firstpage.mp3",
	"island": "res://Audio/Henry Jackman - For Better or Worses island.mp3",
	"forest": "res://Audio/Zak Gott - Forest.mp3",
	"room": "res://Audio/Stafford Bawler - The Garden room.mp3",
}

var _player: AudioStreamPlayer
var _current_path := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)


func play(key: String) -> void:
	var path: String = PATHS.get(key, "")
	if path.is_empty():
		return
	if path == _current_path and _player.playing:
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("BGM not found: %s" % path)
		return

	_set_loop(stream)
	_player.stream = stream
	_player.play()
	_current_path = path


func stop() -> void:
	_player.stop()
	_current_path = ""


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
