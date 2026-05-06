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
var zoom_speed: float = DEFAULT_ZOOM_SPEED
var shift_speed_multiplier: float = DEFAULT_SHIFT_SPEED_MULTIPLIER

# 容器建筑类型标识
const container_type_id: String = "type_01"

# 管道建筑类型标识
const pipe_type_id: String = "type_02"

# 水源建筑类型标识
const water_source_type_id: String = "type_03"

# 流体系统配置
const fluid_flow_rate: float = 0.3 # 每次迭代压力差转移比例 (0.0~1.0)
const fluid_sub_iterations: int = 5 # 每 tick 子迭代次数
const fluid_pressure_threshold: float = 0.02 # 压力差阈值，低于此不推水（防抖动）

# 存档版本号
const SAVE_VERSION: String = "1.0.0"

var save_file_path: String = ""
var keybind_file_path: String = ""
var game_settings_file_path: String = ""

func _ready() -> void:
	_update_save_path()
	_update_keybind_path()
	_update_game_settings_path()
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

	var data = JSON.parse_string(content)
	if data == null or not data is Dictionary:
		push_error("GameConfig: 游戏设置格式无效，使用默认值")
		zoom_speed = DEFAULT_ZOOM_SPEED
		shift_speed_multiplier = DEFAULT_SHIFT_SPEED_MULTIPLIER
		return

	zoom_speed = data.get("zoom_speed", DEFAULT_ZOOM_SPEED)
	shift_speed_multiplier = data.get("shift_speed_multiplier", DEFAULT_SHIFT_SPEED_MULTIPLIER)
	EventBus.game_settings_changed.emit()

func save_game_settings() -> void:
	var settings_data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"zoom_speed": zoom_speed,
		"shift_speed_multiplier": shift_speed_multiplier,
	}

	var dir_path := game_settings_file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(game_settings_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data, "\t"))
		file.close()
	else:
		push_error("GameConfig: 无法写入游戏设置文件: %s" % game_settings_file_path)

# 计算区块像素大小
func get_block_pixel_size() -> int:
	return cell_size * big_cell_size
