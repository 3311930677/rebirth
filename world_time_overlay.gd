extends Control

@export var font_path: String = "res://HYPixel11pxU-2.ttf"

const WEEKDAY_NAMES: PackedStringArray = [
	"日", "一", "二", "三", "四", "五", "六"
]

@onready var _time_label: Label = $ClockPanel/TimeLabel
@onready var _date_label: Label = $ClockPanel/DateLabel
@onready var _seconds_label: Label = $ClockPanel/SecondsLabel

var _last_second: int = -1


func _ready() -> void:
	_apply_font()
	_refresh_display(true)


func _process(_delta: float) -> void:
	_refresh_display(false)


func _apply_font() -> void:
	var font: Font = load(font_path) as Font
	if font == null:
		return
	_time_label.add_theme_font_override("font", font)
	_date_label.add_theme_font_override("font", font)
	_seconds_label.add_theme_font_override("font", font)


func _refresh_display(force: bool) -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour: int = int(now.get("hour", 0))
	var minute: int = int(now.get("minute", 0))
	var second: int = int(now.get("second", 0))
	var year: int = int(now.get("year", 1970))
	var month: int = int(now.get("month", 1))
	var day: int = int(now.get("day", 1))
	var weekday: int = clampi(int(now.get("weekday", 0)), 0, 6)

	_time_label.text = "%02d:%02d" % [hour, minute]
	_seconds_label.text = "%02d" % second
	_date_label.text = "%04d.%02d.%02d  星期%s" % [year, month, day, WEEKDAY_NAMES[weekday]]

	if force or second != _last_second:
		_last_second = second
		var pulse: float = 0.82 + 0.18 * sin(float(second) * TAU / 60.0)
		_seconds_label.modulate = Color(0.72, 0.92, 1.0, pulse)
