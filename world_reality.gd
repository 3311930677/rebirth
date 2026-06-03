extends "res://world_page.gd"

const ScheduleUiHelper = preload("res://schedule_ui_helper.gd")
const SafeTexture = preload("res://safe_texture.gd")
const RealityPlannerPanel = preload("res://reality_planner_panel.gd")
const RealityFloatingTimer = preload("res://reality_floating_timer.gd")
const RESOURCE_DIR := "res://resource"
const FALLBACK_IMAGE_PATHS: PackedStringArray = [
	"res://Sprite/reality.png",
	"res://Sprite/IMG_20260603_162623.jpg",
	"res://Sprite/firstpage.jpg",
	"res://Sprite/room background.jpg",
	"res://Sprite/forest background.jpg",
	"res://Sprite/island background.jpg",
]
const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]
const VIDEO_EXTENSIONS: PackedStringArray = ["ogv", "mp4", "webm", "mov"]
const IMAGE_DURATION_SEC := 30.0
const VIDEO_PLAY_COUNT := 5

var _image_paths: Array[String] = []
var _all_media: Array[Dictionary] = []

var _using_video := false
var _image_elapsed := 0.0
var _video_play_count := 0
var _bg_video: VideoStreamPlayer = null
var _viewport_camera: Camera2D = null
var _calendar: Control = null
var _planner_panel: Control = null
var _schedule_button: Button = null
var _todo_button: Button = null
var _resources_button: Button = null
var _timer_toggle_button: Button = null
var _timer_place_button: Button = null
var _floating_timer: Control = null
var _world_time_overlay: Control = null
var _video_bg_texture: Texture2D = null


func _ready() -> void:
	_collect_resource_media()
	super._ready()
	_viewport_camera = get_node_or_null("ViewportCamera") as Camera2D
	_calendar = $UI/ScheduleCalendar as Control
	_world_time_overlay = $UI/WorldTimeOverlay as Control
	_schedule_button = $UI/ScheduleButton as Button
	_todo_button = $UI/TodoButton as Button
	_resources_button = $UI/ResourcesButton as Button
	_timer_toggle_button = $UI/TimerToggleButton as Button
	_timer_place_button = $UI/TimerPlaceButton as Button
	_setup_planner_panel()
	_setup_floating_timer()
	_apply_menu_button_fonts()
	ScheduleUiHelper.bind_calendar(
		_calendar,
		_on_calendar_closed,
		_schedule_button,
		_toggle_calendar
	)
	_center_viewport_camera()
	_update_reality_hint()
	if _all_media.is_empty():
		push_warning("reality 世界：%s 中没有媒体文件，使用内置备用图。" % RESOURCE_DIR)
		_use_fallback_image()
		return
	_pick_random_background()


func _on_viewport_size_changed() -> void:
	super._on_viewport_size_changed()
	_center_viewport_camera()


func _place_player_at_center() -> void:
	_center_viewport_camera()


func _center_viewport_camera() -> void:
	if _viewport_camera == null:
		return
	_viewport_camera.global_position = get_viewport().get_visible_rect().size * 0.5


func _build_world_progress_snapshot() -> Dictionary:
	return {}


func _apply_world_progress_snapshot(_snapshot: Dictionary) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if _calendar != null and _calendar.visible:
		return
	if _planner_panel != null and _planner_panel.visible:
		return
	if ScheduleUiHelper.handle_open_key(event):
		_toggle_calendar()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _input(event: InputEvent) -> void:
	if _calendar != null and _calendar.visible:
		return
	if _planner_panel != null and _planner_panel.visible:
		return
	if ScheduleUiHelper.handle_open_key(event):
		_toggle_calendar()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	super._input(event)


func _toggle_calendar() -> void:
	if _planner_panel != null and _planner_panel.visible:
		_planner_panel.close_panel()
	ScheduleUiHelper.toggle(_calendar, null, false)
	_update_reality_hint()


func _on_calendar_closed() -> void:
	_update_reality_hint()


func _setup_planner_panel() -> void:
	if _planner_panel != null:
		return
	_planner_panel = RealityPlannerPanel.new()
	_planner_panel.name = "RealityPlannerPanel"
	$UI.add_child(_planner_panel)
	if _planner_panel.has_signal("closed"):
		_planner_panel.closed.connect(_on_planner_closed)
	if _todo_button != null:
		_todo_button.pressed.connect(_open_todo_panel)
	if _resources_button != null:
		_resources_button.pressed.connect(_open_resources_panel)


func _setup_floating_timer() -> void:
	if _floating_timer != null:
		return
	_floating_timer = RealityFloatingTimer.new()
	_floating_timer.name = "RealityFloatingTimer"
	$UI.add_child(_floating_timer)
	if _floating_timer.has_signal("timer_visibility_changed"):
		_floating_timer.timer_visibility_changed.connect(func(_visible: bool) -> void: _update_timer_button_text())
	_update_timer_button_text()
	if _timer_toggle_button != null:
		_timer_toggle_button.pressed.connect(_toggle_floating_timer)
	if _timer_place_button != null:
		_timer_place_button.pressed.connect(_place_floating_timer)


func _open_todo_panel() -> void:
	if _calendar != null and _calendar.visible:
		_calendar.close_calendar()
	_set_planner_companion_ui(true)
	if _planner_panel != null:
		_planner_panel.open_panel("todo")
	_update_reality_hint()


func _open_resources_panel() -> void:
	if _calendar != null and _calendar.visible:
		_calendar.close_calendar()
	_set_planner_companion_ui(true)
	if _planner_panel != null:
		_planner_panel.open_panel("resources")
	_update_reality_hint()


func _on_planner_closed() -> void:
	_set_planner_companion_ui(false)
	_update_reality_hint()


func _set_planner_companion_ui(show_planner: bool) -> void:
	if _world_time_overlay != null:
		_world_time_overlay.visible = not show_planner
	if _schedule_button != null:
		_schedule_button.visible = not show_planner
	if _todo_button != null:
		_todo_button.visible = not show_planner
	if _resources_button != null:
		_resources_button.visible = not show_planner
	if _timer_toggle_button != null:
		_timer_toggle_button.visible = not show_planner
	if _timer_place_button != null:
		_timer_place_button.visible = not show_planner


func _toggle_floating_timer() -> void:
	if _floating_timer != null and _floating_timer.has_method("toggle_visibility"):
		_floating_timer.call("toggle_visibility")
	_update_timer_button_text()


func _place_floating_timer() -> void:
	if _floating_timer != null and _floating_timer.has_method("place_bottom_left"):
		_floating_timer.call("place_bottom_left")
	_update_timer_button_text()


func _update_timer_button_text() -> void:
	if _timer_toggle_button == null or _floating_timer == null:
		return
	var visible_timer := false
	if _floating_timer.has_method("is_visible_timer"):
		visible_timer = bool(_floating_timer.call("is_visible_timer"))
	_timer_toggle_button.text = "隐藏计时" if visible_timer else "显示计时"


func _apply_menu_button_fonts() -> void:
	var font: Font = load("res://HYPixel11pxU-2.ttf") as Font
	for btn in [_schedule_button, _todo_button, _resources_button, _timer_toggle_button, _timer_place_button]:
		if btn == null:
			continue
		if font != null:
			btn.add_theme_font_override("font", font)


func _update_reality_hint() -> void:
	if _hint == null:
		return
	if _calendar != null and _calendar.visible:
		_hint.text = "Esc 关闭日程"
		return
	if _planner_panel != null and _planner_panel.visible:
		_hint.text = "Esc 关闭面板"
		return
	var timer_hint := ""
	if _floating_timer != null and _floating_timer.has_method("is_visible_timer"):
		if bool(_floating_timer.call("is_visible_timer")):
			timer_hint = "  左下角可拖动计时器。"
	_hint.text = EscExitHelper.hint_text(
		_esc_confirm_pending,
		"Esc 返回世界选择%s" % timer_hint,
		"再按 Enter 确认返回世界选择"
	)


func _process(delta: float) -> void:
	super._process(delta)
	if _all_media.is_empty():
		return

	if _using_video:
		_sync_video_to_background()
		return

	_image_elapsed += delta
	if _image_elapsed >= IMAGE_DURATION_SEC:
		_pick_random_background()


func _collect_resource_media() -> void:
	_image_paths.clear()
	_all_media.clear()

	var dir: DirAccess = DirAccess.open(RESOURCE_DIR)
	if dir == null:
		return

	for raw_name in dir.get_files():
		var file_name: String = str(raw_name)
		if file_name.ends_with(".uid"):
			continue
		var ext: String = file_name.get_extension().to_lower()
		var full_path: String = RESOURCE_DIR.path_join(file_name)
		if ext in IMAGE_EXTENSIONS:
			_image_paths.append(full_path)
			_all_media.append({"type": "image", "path": full_path})
		elif ext in VIDEO_EXTENSIONS:
			_all_media.append({"type": "video", "path": full_path})

	if _image_paths.is_empty():
		for path in FALLBACK_IMAGE_PATHS:
			if ResourceLoader.exists(path):
				_image_paths.append(path)


func _pick_random_background() -> void:
	if _all_media.is_empty():
		return

	_stop_video_background()
	_image_elapsed = 0.0
	_video_play_count = 0

	var entry: Dictionary = _all_media[randi() % _all_media.size()]
	var media_type: String = str(entry.get("type", ""))
	var path: String = str(entry.get("path", ""))
	if path.is_empty():
		return

	if media_type == "video":
		_start_video_background(path)
	else:
		_start_image_background(path)


func _start_image_background(path: String) -> void:
	_using_video = false
	if _background == null:
		return
	_background.visible = true
	_background.modulate = Color(1, 1, 1, 1)
	var tex: Texture2D = SafeTexture.load_from_path(path)
	if tex == null:
		_use_fallback_image()
		return
	_apply_background_texture(tex)


func _start_video_background(path: String) -> void:
	var stream: VideoStream = _load_video_stream(path)
	if stream == null:
		if not _image_paths.is_empty():
			_start_image_background(_image_paths[randi() % _image_paths.size()])
		return

	_using_video = true
	_video_bg_texture = null
	if _background != null:
		_background.visible = true
		_background.modulate = Color(1, 1, 1, 1)

	_bg_video = VideoStreamPlayer.new()
	_bg_video.name = "RealityBgVideo"
	_bg_video.stream = stream
	_bg_video.visible = false
	add_child(_bg_video)
	_bg_video.finished.connect(_on_reality_video_finished)
	if not _image_paths.is_empty():
		var placeholder: Texture2D = SafeTexture.load_from_path(_image_paths[0])
		if placeholder != null:
			_apply_background_texture(placeholder)
	_bg_video.play()


func _sync_video_to_background() -> void:
	if _bg_video == null or _background == null:
		return
	var video_texture: Texture2D = _bg_video.get_video_texture() as Texture2D
	if video_texture == null:
		return

	var tex_size: Vector2i = video_texture.get_size()
	var needs_clamp: bool = (
		tex_size.x > SafeTexture.MAX_TEXTURE_SIZE
		or tex_size.y > SafeTexture.MAX_TEXTURE_SIZE
	)
	var display_texture: Texture2D = video_texture
	if needs_clamp:
		display_texture = SafeTexture.clamp_texture(video_texture)
	if display_texture == null:
		return
	if not needs_clamp and _background.texture == display_texture:
		return
	if needs_clamp or _video_bg_texture != display_texture:
		_video_bg_texture = display_texture
		_apply_background_texture(display_texture)


func _on_reality_video_finished() -> void:
	_video_play_count += 1
	if _video_play_count >= VIDEO_PLAY_COUNT:
		_pick_random_background()
		return
	if _bg_video != null:
		_bg_video.play()


func _stop_video_background() -> void:
	_using_video = false
	_video_bg_texture = null
	if _bg_video != null:
		if _bg_video.finished.is_connected(_on_reality_video_finished):
			_bg_video.finished.disconnect(_on_reality_video_finished)
		_bg_video.queue_free()
		_bg_video = null


func _apply_background_texture(texture: Texture2D) -> void:
	if _background == null or texture == null:
		return
	_background.visible = true
	_background.texture = texture
	_background.modulate = Color(1, 1, 1, 1)
	_apply_background_scale()
	_center_viewport_camera()


func _use_fallback_image() -> void:
	_using_video = false
	_stop_video_background()
	if _image_paths.is_empty():
		return
	_start_image_background(_image_paths[randi() % _image_paths.size()])


func _load_video_stream(path: String) -> VideoStream:
	if path.is_empty():
		return null

	var candidates: Array[String] = []
	var ext: String = path.get_extension().to_lower()
	if ext == "mov":
		candidates.append("%s.ogv" % path.get_basename())
	else:
		candidates.append(path)
		if ext != "ogv":
			candidates.append("%s.ogv" % path.get_basename())

	for candidate in candidates:
		if not ResourceLoader.exists(candidate):
			continue
		var loaded: Resource = ResourceLoader.load(candidate)
		if loaded is VideoStream:
			return loaded as VideoStream

	return null
