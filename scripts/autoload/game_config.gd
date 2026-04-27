extends Node

# 网格配置
@export var cell_size: int = 64
@export var big_cell_size: int = 10

# 线条配置
@export var thin_line_width: float = 1.0
@export var thick_line_width: float = 3.0

# 颜色配置
@export var background_color: Color = Color("#1e3a5f")
@export var line_color: Color = Color("#e0e0e0", 0.5)

# 建筑配置
@export var building_size: int = 60
@export var building_border: int = 2
@export var building_default_color: Color = Color("#2ecc71")

# 存档版本号
const SAVE_VERSION: String = "1.0.0"

var save_file_path: String = ""
var keybind_file_path: String = ""

func _ready() -> void:
	_update_save_path()
	_update_keybind_path()

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

# 计算区块像素大小
func get_block_pixel_size() -> int:
	return cell_size * big_cell_size
