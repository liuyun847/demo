extends Label

# 右上角帧率显示组件
# 每 0.5 秒更新一次 FPS，带灰底背景

const MARGIN := Vector2(10, 10)
const MIN_UPDATE_INTERVAL := 0.5  # 更新间隔（秒）

var _time_elapsed := 0.0
var _frame_count := 0
var _fps := 0.0

func _ready() -> void:
	# 固定在右上角，宽度缩短到一半（100px）
	anchors_preset = Control.PRESET_TOP_RIGHT
	offset_left = -100
	offset_top = int(MARGIN.y)
	offset_right = -int(MARGIN.x)
	offset_bottom = int(MARGIN.y) + 24

	# 灰底背景
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	add_theme_stylebox_override("normal", bg)

	# 文字样式（居中）
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))

	text = "FPS: --"

func _process(delta: float) -> void:
	_time_elapsed += delta
	_frame_count += 1

	if _time_elapsed >= MIN_UPDATE_INTERVAL:
		_fps = _frame_count / _time_elapsed
		text = "FPS: %d" % int(_fps)
		_frame_count = 0
		_time_elapsed = 0.0
