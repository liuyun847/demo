extends Node

const FileIOHelper := preload("res://scripts/utils/file_io_helper.gd")

# 网格配置
const CELL_SIZE: int = 64
const BIG_CELL_SIZE: int = 10
## 无效格子坐标哨兵，用于表示"未设置"状态
const INVALID_GRID_POS: Vector2i = Vector2i(-99999, -99999)

# 线条配置
const THIN_LINE_WIDTH: float = 1.0
const THICK_LINE_WIDTH: float = 3.0
## 可见大格子数超过此阈值时隐藏细线，避免渲染过载
const THIN_LINE_VISIBLE_THRESHOLD: int = 6

# 颜色配置
const BACKGROUND_COLOR: Color = Color("#1e3a5f")
const LINE_COLOR: Color = Color("#e0e0e0", 0.5)

# 建筑配置
const BUILDING_SIZE: int = 60
const BUILDING_BORDER: int = 2
const BUILDING_DEFAULT_COLOR: Color = Color("#2ecc71")
const GHOST_ALPHA: float = 0.35
const REMOVE_GHOST_ALPHA: float = 0.3

const SELECTION_HIGHLIGHT_COLOR: Color = Color(0.2, 0.6, 1.0, 0.4)
const SELECTION_BORDER_COLOR: Color = Color(0.2, 0.6, 1.0, 0.8)
const PASTE_GHOST_ALPHA: float = 0.45

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

# 核心建筑类型标识（旧存档跳过用）
const CORE_TYPE_ID: String = "type_00"

# 管道建筑类型标识（旧存档兼容，无实际用途）
const PIPE_TYPE_ID: String = "type_02"

# 砖块建筑类型标识（旧存档兼容，无实际用途）
const BRICK_TYPE_ID: String = "type_04"

# 源头建筑类型标识（旧存档兼容，无实际用途）
const SOURCE_TYPE_ID: String = "type_03"

# 收集器建筑类型标识（旧存档兼容，无实际用途）
const COLLECTOR_TYPE_ID: String = "type_07"

# 建筑放置源质消耗（key: building_type_id, value: cost；纯搭建阶段全为默认 0）
const BUILDING_ESSENCE_COSTS: Dictionary = {}

# 初始源质
const INITIAL_ESSENCE: float = 100.0

# 模拟系统配置
const SIMULATION_TICK_INTERVAL: float = 0.1

# 存档版本号
const SAVE_VERSION: String = "1.0.0"

# 统一存档文件名（单文件存档：buildings + settings + keybindings 合并到此 .cfg）
const UNIFIED_SAVE_FILE_NAME: String = "game.cfg"

# ConfigFile 的 section 名称
const SECTION_BUILDINGS: String = "buildings"
const SECTION_SETTINGS: String = "settings"
const SECTION_KEYBINDINGS: String = "keybindings"

# 统一存档路径（单文件 .cfg）
var unified_save_path: String = ""
# 旧版 JSON 存档路径，仅用于启动时迁移到 .cfg 后重命名备份
var legacy_save_file_path: String = ""
var legacy_keybind_file_path: String = ""
var legacy_game_settings_file_path: String = ""

func _init() -> void:
	_update_unified_save_path()
	_update_legacy_paths()

func _ready() -> void:
	BuildingTypeManager.register_defaults()
	_migrate_legacy_saves()
	load_game_settings()

func _get_config_file_path(file_name: String) -> String:
	if OS.has_feature("editor"):
		return "res://save/%s" % file_name
	else:
		var exe_path := OS.get_executable_path()
		var install_dir := exe_path.get_base_dir()
		return install_dir.path_join("save/%s" % file_name)

func _update_unified_save_path() -> void:
	unified_save_path = _get_config_file_path(UNIFIED_SAVE_FILE_NAME)

func _update_legacy_paths() -> void:
	legacy_save_file_path = _get_config_file_path("buildings.json")
	legacy_keybind_file_path = _get_config_file_path("keybindings.json")
	legacy_game_settings_file_path = _get_config_file_path("game_settings.json")

## 迁移旧版多 JSON 存档到统一 .cfg 文件
## 仅在 .cfg 不存在且存在任意旧 .json 时执行，迁移后将旧文件重命名为 .json.bak
func _migrate_legacy_saves() -> void:
	# .cfg 已存在则跳过迁移
	if FileAccess.file_exists(unified_save_path):
		return

	var has_any_legacy: bool = (
		FileAccess.file_exists(legacy_save_file_path)
		or FileAccess.file_exists(legacy_keybind_file_path)
		or FileAccess.file_exists(legacy_game_settings_file_path)
	)
	if not has_any_legacy:
		return

	# 依次迁移三个旧 JSON 到 .cfg 的对应 section（缺失的跳过）
	_migrate_one_legacy_file(legacy_save_file_path, SECTION_BUILDINGS, "SaveManager")
	_migrate_one_legacy_file(legacy_game_settings_file_path, SECTION_SETTINGS, "GameConfig")
	_migrate_one_legacy_file(legacy_keybind_file_path, SECTION_KEYBINDINGS, "KeybindManager")

## 迁移单个旧 JSON 文件到 .cfg 指定 section，成功后重命名为 .json.bak
func _migrate_one_legacy_file(legacy_path: String, section: String, module_name: String) -> void:
	if not FileAccess.file_exists(legacy_path):
		return
	# 旧 JSON 不强制版本校验，尽力迁移
	var result := FileIOHelper.read_json_file(legacy_path, module_name)
	if not result.success:
		push_warning("GameConfig: 旧存档迁移失败，跳过 %s: %s" % [legacy_path, result.error_message])
		return
	if not FileIOHelper.migrate_json_to_cfg_section(
		unified_save_path, section, result.data, "GameConfig"
	):
		push_warning("GameConfig: 写入 .cfg section [%s] 失败，跳过 %s" % [section, legacy_path])
		return
	# 迁移成功，重命名旧文件为 .bak 防止再次迁移
	var bak_path := legacy_path + ".bak"
	var rename_err := DirAccess.rename_absolute(legacy_path, bak_path)
	if rename_err != OK:
		push_warning("GameConfig: 无法重命名旧存档 %s (错误码: %d)" % [legacy_path, rename_err])
	else:
		print("GameConfig: 已迁移旧存档 %s -> .cfg [%s]" % [legacy_path, section])

func load_game_settings() -> void:
	if not FileIOHelper.cfg_has_section(unified_save_path, SECTION_SETTINGS):
		return

	# 游戏设置不强制版本校验，兼容旧版无 version 字段
	var result := FileIOHelper.read_cfg_section(
		unified_save_path,
		SECTION_SETTINGS,
		"GameConfig"
	)

	if not result.success:
		push_warning(result.error_message)
		zoom_speed = DEFAULT_ZOOM_SPEED
		shift_speed_multiplier = DEFAULT_SHIFT_SPEED_MULTIPLIER
		return

	var data: Dictionary = result.data
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

	if not FileIOHelper.write_cfg_section(
		unified_save_path, SECTION_SETTINGS, settings_data, "GameConfig"
	):
		push_error("GameConfig: 游戏设置保存失败")

