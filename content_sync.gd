extends Node

## 可选联网：在 user://content_sync.cfg 里配置远程 manifest 地址。
## manifest 示例见 data/content_manifest.example.json

signal sync_finished(success: bool, message: String)

const CONFIG_PATH := "user://content_sync.cfg"
const MANIFEST_KEY := "manifest_url"
const LAST_SYNC_KEY := "last_sync_unix"

var _http: HTTPRequest
var _pending_kind: String = ""
var _manifest: Dictionary = {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	if should_auto_sync():
		sync_now()


func get_manifest_url() -> String:
	var cfg := _load_config()
	return str(cfg.get(MANIFEST_KEY, "")).strip_edges()


func set_manifest_url(url: String) -> void:
	var cfg := _load_config()
	cfg[MANIFEST_KEY] = url.strip_edges()
	_save_config(cfg)


func should_auto_sync() -> bool:
	return not get_manifest_url().is_empty()


func sync_now() -> void:
	var url: String = get_manifest_url()
	if url.is_empty():
		sync_finished.emit(false, "未配置 manifest_url")
		return
	_request_json(url, "manifest")


func _request_json(url: String, kind: String) -> void:
	_pending_kind = kind
	var err: Error = _http.request(url)
	if err != OK:
		_pending_kind = ""
		sync_finished.emit(false, "请求失败: %s" % str(err))


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var kind := _pending_kind
	_pending_kind = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		sync_finished.emit(false, "网络错误 HTTP %d" % response_code)
		return

	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		sync_finished.emit(false, "JSON 解析失败")
		return

	match kind:
		"manifest":
			_handle_manifest(parsed as Dictionary)
		"schedule":
			ScheduleData.apply_remote_payload(parsed as Dictionary)
			_mark_synced()
			sync_finished.emit(true, "日程已更新")
		_:
			sync_finished.emit(false, "未知响应类型")


func _handle_manifest(manifest: Dictionary) -> void:
	_manifest = manifest
	var schedule_url: String = str(manifest.get("schedule_url", "")).strip_edges()
	if schedule_url.is_empty():
		sync_finished.emit(true, "manifest 无 schedule_url")
		return
	_request_json(schedule_url, "schedule")


func _mark_synced() -> void:
	var cfg := _load_config()
	cfg[LAST_SYNC_KEY] = Time.get_unix_time_from_system()
	_save_config(cfg)


func _load_config() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return {}
	return {
		MANIFEST_KEY: str(cfg.get_value("sync", MANIFEST_KEY, "")),
		LAST_SYNC_KEY: int(cfg.get_value("sync", LAST_SYNC_KEY, 0)),
	}


func _save_config(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("sync", MANIFEST_KEY, data.get(MANIFEST_KEY, ""))
	cfg.set_value("sync", LAST_SYNC_KEY, data.get(LAST_SYNC_KEY, 0))
	cfg.save(CONFIG_PATH)
