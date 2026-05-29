extends Node2D

const EscExitHelper = preload("res://esc_exit_helper.gd")

@export var world_name: String = "world"
@export var background_path: String = ""
@export var background_scale: float = 1.08
@export var return_scene_path: String = "res://sky_select.tscn"
@export var intro_frames_dir: String = ""
@export var intro_fps: float = 12.0
@export var intro_video_path: String = ""

@onready var _background: Sprite2D = $MapBackground
@onready var _player: CharacterBody2D = $Player
@onready var _hint: Label = $UI/HintLabel
@onready var _ui_layer: CanvasLayer = $UI
@onready var _intro_overlay: Control = get_node_or_null("UI/IntroOverlay") as Control
@onready var _intro_image: TextureRect = get_node_or_null("UI/IntroOverlay/IntroImage") as TextureRect

var _esc_confirm_pending := false
var _intro_frames: Array[Texture2D] = []
var _intro_frame_index := 0
var _intro_elapsed := 0.0
var _intro_playing := false
var _intro_video: VideoStreamPlayer = null
var _intro_video_overlay: Control = null
var _intro_video_rect: TextureRect = null

func _ready() -> void:
	BgmPlayer.play(world_name)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_background()
	_place_player_at_center()
	if _player != null:
		_player.refresh_movement_bounds()
	_update_hint_text()
	_prepare_intro()
	_play_intro_if_any()

func is_intro_video_playing() -> bool:
	return _intro_playing

func _process(delta: float) -> void:
	if not _intro_playing:
		return

	if _intro_video != null:
		var video_texture: Texture2D = _intro_video.get_video_texture()
		if video_texture != null and _intro_video_rect != null:
			_intro_video_rect.texture = video_texture
		return

	_intro_elapsed += delta
	var frame: int = int(_intro_elapsed * intro_fps)
	if frame >= _intro_frames.size():
		_finish_intro()
		return
	if frame != _intro_frame_index and _intro_image != null:
		_intro_frame_index = frame
		_intro_image.texture = _intro_frames[frame]

func _on_viewport_size_changed() -> void:
	if not is_node_ready():
		return
	_apply_background_scale()
	_place_player_at_center()
	if _player != null:
		_player.refresh_movement_bounds()
	_fit_intro_video_overlay()
	_fit_intro_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if EscExitHelper.handle_input(
		event,
		_esc_confirm_pending,
		return_scene_path,
		get_tree(),
		_set_esc_confirm_pending
	):
		return

func _set_esc_confirm_pending(pending: bool) -> void:
	_esc_confirm_pending = pending
	_update_hint_text()

func _apply_background() -> void:
	if _background.texture == null and not background_path.is_empty():
		_background.texture = load(background_path) as Texture2D
	if _background.texture != null:
		_background.modulate = Color(1, 1, 1, 1)
	else:
		_background.modulate = Color(0, 0, 0, 1)
	_apply_background_scale()

func _apply_background_scale() -> void:
	if _background.texture == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = _background.texture.get_size()
	var cover_scale: float = maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y) * background_scale
	_background.scale = Vector2.ONE * cover_scale
	_background.position = viewport_size * 0.5

func _place_player_at_center() -> void:
	if _player == null or _background.texture == null:
		return
	_player.global_position = _background.global_position

func _update_hint_text() -> void:
	_hint.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		"Esc 返回世界选择",
		"再按 Enter 确认返回世界选择"
	)

func _prepare_intro() -> void:
	_intro_frames.clear()
	if not intro_video_path.is_empty() or intro_frames_dir.is_empty():
		return

	var dir: DirAccess = DirAccess.open(intro_frames_dir)
	if dir == null:
		return

	var names: Array[String] = []
	for file_name in dir.get_files():
		if file_name.to_lower().ends_with(".png"):
			names.append(file_name)
	names.sort()

	for file_name in names:
		var tex: Texture2D = load(intro_frames_dir.path_join(file_name)) as Texture2D
		if tex != null:
			_intro_frames.append(tex)

func _play_intro_if_any() -> void:
	if not intro_video_path.is_empty():
		_play_intro_video()
		return

	if _intro_frames.is_empty() or _intro_overlay == null or _intro_image == null:
		if _intro_overlay != null:
			_intro_overlay.visible = false
		return

	_fit_intro_overlay()
	_intro_frame_index = 0
	_intro_elapsed = 0.0
	_intro_playing = true
	_intro_overlay.visible = true
	_intro_image.texture = _intro_frames[0]
	if _player != null:
		_player.set_physics_process(false)

func _finish_intro() -> void:
	_cleanup_intro_video()
	if _intro_overlay != null:
		_intro_overlay.visible = false
	_release_player_after_intro()

func _on_intro_video_finished() -> void:
	_cleanup_intro_video()
	_on_intro_sequence_complete()

func _on_intro_sequence_complete() -> void:
	_release_player_after_intro()

func _release_player_after_intro() -> void:
	_intro_playing = false
	if _player != null:
		_player.set_physics_process(true)
		_player.visible = true

func _play_intro_video() -> void:
	var stream := _load_intro_video_stream(intro_video_path)
	if stream == null or _background == null:
		push_warning("Intro video not found: %s" % intro_video_path)
		return

	_intro_video = VideoStreamPlayer.new()
	_intro_video.name = "IntroVideoDecoder"
	_intro_video.stream = stream
	_intro_video.visible = false
	add_child(_intro_video)

	_intro_video_overlay = Control.new()
	_intro_video_overlay.name = "IntroVideoOverlay"
	_intro_video_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_video_overlay.clip_contents = true
	_ui_layer.add_child(_intro_video_overlay)

	_intro_video_rect = TextureRect.new()
	_intro_video_rect.name = "IntroVideoRect"
	_intro_video_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intro_video_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_intro_video_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_video_overlay.add_child(_intro_video_rect)

	_fit_intro_video_overlay()
	_intro_video.finished.connect(_on_intro_video_finished)
	_intro_playing = true
	_intro_video.play()
	if _player != null:
		_player.set_physics_process(false)
		_player.visible = false

func _cleanup_intro_video() -> void:
	if _intro_video_overlay != null:
		_intro_video_overlay.queue_free()
		_intro_video_overlay = null
		_intro_video_rect = null
	if _intro_video != null:
		_intro_video.queue_free()
		_intro_video = null

func _load_intro_video_stream(path: String) -> VideoStream:
	var stream := load(path) as VideoStream
	if stream != null:
		return stream

	if path.get_extension().to_lower() == "mov":
		var ogv_path := "%s.ogv" % path.get_basename()
		return load(ogv_path) as VideoStream

	return null

func _get_background_display_rect() -> Rect2:
	if _background == null or _background.texture == null:
		return Rect2()
	var tex_size: Vector2 = _background.texture.get_size()
	var display_size: Vector2 = tex_size * _background.scale
	return Rect2(_background.global_position - display_size * 0.5, display_size)

func _fit_intro_video_overlay() -> void:
	if _intro_video_overlay == null:
		return
	var rect: Rect2 = _get_background_display_rect()
	_intro_video_overlay.position = rect.position
	_intro_video_overlay.size = rect.size
	if _intro_video_rect != null:
		_intro_video_rect.position = Vector2.ZERO
		_intro_video_rect.size = rect.size

func _fit_intro_overlay() -> void:
	if _intro_overlay == null or _intro_image == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_intro_overlay.position = Vector2.ZERO
	_intro_overlay.size = viewport_size
	_intro_image.position = Vector2.ZERO
	_intro_image.size = viewport_size
