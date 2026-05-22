extends Node

# 网格配置
const cell_size: int = 64
const big_cell_size: int = 10

# 线条配置
const thin_line_width: float = 1.0
const thick_line_width: float = 3.0

# 颜色配置
const background_color: Color = Color("#1e3a5f")
const line_color: Color = Color("#e0e0e0", 0.5)

# 建筑配置
const building_size: int = 60
const building_border: int = 2
const building_default_color: Color = Color("#2ecc71")
const ghost_alpha: float = 0.35
const remove_ghost_alpha: float = 0.3

const selection_highlight_color: Color = Color(0.2, 0.6, 1.0, 0.4)
const selection_border_color: Color = Color(0.2, 0.6, 1.0, 0.8)
const paste_ghost_alpha: float = 0.45

# 游戏数值设置
const DEFAULT_ZOOM_SPEED: float = 0.2
const DEFAULT_SHIFT_SPEED_MULTIPLIER: float = 5.0
const ZOOM_SPEED_MIN: float = 0.01
const ZOOM_SPEED_MAX: float = 0.5
const SHIFT_MULTIPLIER_MIN: float = 1.0
const SHIFT_MULTIPLIER_MAX: float = 10.0
var zoom_speed: float = DEFAULT_ZOOM_SPEED:
	set(value):
		zoom_speed = clampf(value, ZOOM_SPEED_MIN, ZOOM_SPEED_MAX)
var shift_speed_multiplier: float = DEFAULT_SHIFT_SPEED_MULTIPLIER:
	set(value):
		shift_speed_multiplier = clampf(value, SHIFT_MULTIPLIER_MIN, SHIFT_MULTIPLIER_MAX)

# 容器建筑类型标识
const container_type_id: String = "type_01"

# 管道建筑类型标识
const pipe_type_id: String = "type_02"

# 砖块建筑类型标识
const brick_type_id: String = "type_04"

# 反应系统配置
const reaction_tick_interval: float = 0.3 # 反应系统每 tick 间隔（秒）
const diffusion_steps_per_tick: int = 3   # 每 tick 扩散步数

# 存档版本号
const SAVE_VERSION: String = "1.0.0"

var save_file_path: String = ""
var keybind_file_path: String = ""
var game_settings_file_path: String = ""

func _init() -> void:
	_update_save_path()
	_update_keybind_path()
	_update_game_settings_path()

func _ready() -> void:
	load_game_settings()

func _get_config_file_path(file_name: String) -> String:
	if OS.has_feature("editor"):
		return "res://save/%s" % file_name
	else:
		var exe_path := OS.get_executable_path()
		var install_dir := exe_path.get_base_dir()
		return install_dir.path_join("save/%s" % file_name)

func _update_save_path() -> void:
	save_file_path = _get_config_file_path("buildings.json")

func _update_keybind_path() -> void:
	keybind_file_path = _get_config_file_path("keybindings.json")

func _update_game_settings_path() -> void:
	game_settings_file_path = _get_config_file_path("game_settings.json")

func load_game_settings() -> void:
	if not FileAccess.file_exists(game_settings_file_path):
		return

	var file := FileAccess.open(game_settings_file_path, FileAccess.READ)
	if not file:
		push_error("GameConfig: 无法读取游戏设置文件: %s" % game_settings_file_path)
		return

	var content := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(content)
	if data == null or not data is Dictionary:
		push_error("GameConfig: 游戏设置格式无效，使用默认值")
		zoom_speed = DEFAULT_ZOOM_SPEED
		shift_speed_multiplier = DEFAULT_SHIFT_SPEED_MULTIPLIER
		return

	var zoom_val: Variant = data.get("zoom_speed", DEFAULT_ZOOM_SPEED)
	var shift_val: Variant = data.get("shift_speed_multiplier", DEFAULT_SHIFT_SPEED_MULTIPLIER)
	zoom_speed = zoom_val if zoom_val is float or zoom_val is int else DEFAULT_ZOOM_SPEED
	shift_speed_multiplier = shift_val if shift_val is float or shift_val is int else DEFAULT_SHIFT_SPEED_MULTIPLIER

func save_game_settings() -> void:
	var settings_data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"zoom_speed": zoom_speed,
		"shift_speed_multiplier": shift_speed_multiplier,
	}

	var dir_path := game_settings_file_path.get_base_dir()
	var dir_result := DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_result != OK:
		push_error("GameConfig: 无法创建设置目录: %s (错误码: %d)" % [dir_path, dir_result])
		return

	var file := FileAccess.open(game_settings_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data, "\t"))
		file.close()
	else:
		push_error("GameConfig: 无法写入游戏设置文件: %s" % game_settings_file_path)

# 计算区块像素大小
func get_block_pixel_size() -> int:
	return cell_size * big_cell_size
