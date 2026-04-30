extends Node

# 网格配置
var cell_size: int = 64
var big_cell_size: int = 10

# 线条配置
var thin_line_width: float = 1.0
var thick_line_width: float = 3.0

# 颜色配置
var background_color: Color = Color("#1e3a5f")
var line_color: Color = Color("#e0e0e0", 0.5)

# 建筑配置
var building_size: int = 60
var building_border: int = 2
var building_default_color: Color = Color("#2ecc71")
var ghost_alpha: float = 0.35
var remove_ghost_alpha: float = 0.3

# 游戏数值设置
var zoom_speed: float = 0.2
var shift_speed_multiplier: float = 5.0

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

func _update_save_path() -> void:
	if OS.has_feature("editor"):
		save_file_path = "res://save/buildings.json"
	else:
		var exe_path := OS.get_executable_path()
		var install_dir := exe_path.get_base_dir()
		save_file_path = install_dir.path_join("save/buildings.json")

func _update_keybind_path() -> void:
	if OS.has_feature("editor"):
		keybind_file_path = "res://save/keybindings.json"
	else:
		var exe_path := OS.get_executable_path()
		var install_dir := exe_path.get_base_dir()
		keybind_file_path = install_dir.path_join("save/keybindings.json")

func _update_game_settings_path() -> void:
	if OS.has_feature("editor"):
		game_settings_file_path = "res://save/game_settings.json"
	else:
		var exe_path := OS.get_executable_path()
		var install_dir := exe_path.get_base_dir()
		game_settings_file_path = install_dir.path_join("save/game_settings.json")

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
		push_error("GameConfig: 游戏设置格式无效")
		return

	if data.has("zoom_speed") and data.zoom_speed is float:
		zoom_speed = data.zoom_speed
	if data.has("shift_speed_multiplier") and data.shift_speed_multiplier is float:
		shift_speed_multiplier = data.shift_speed_multiplier

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
