extends GutTest

const FileIOHelper := preload("res://scripts/utils/file_io_helper.gd")

func test_building_type_constants() -> void:
	assert_eq(GameConfig.CORE_TYPE_ID, "type_00", "core_type_id 应为 type_00")
	assert_eq(GameConfig.PIPE_TYPE_ID, "type_02", "pipe_type_id 应为 type_02")

func test_simulation_config_constants() -> void:
	assert_eq(GameConfig.SIMULATION_TICK_INTERVAL, 0.1, "simulation_tick_interval 应为 0.1")

func test_save_and_load_settings() -> void:
	var original_save_path: String = GameConfig.unified_save_path
	GameConfig.unified_save_path = "res://save/test_game_settings.cfg"

	_cleanup_test_settings()
	var original_zoom: float = GameConfig.zoom_speed
	var original_shift: float = GameConfig.shift_speed_multiplier

	GameConfig.zoom_speed = 0.15
	GameConfig.shift_speed_multiplier = 3.0
	GameConfig.save_game_settings()

	GameConfig.zoom_speed = GameConfig.DEFAULT_ZOOM_SPEED
	GameConfig.shift_speed_multiplier = GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER
	GameConfig.load_game_settings()

	assert_eq(GameConfig.zoom_speed, 0.15, "加载后 zoom_speed 应恢复为 0.15")
	assert_eq(GameConfig.shift_speed_multiplier, 3.0, "加载后 shift_speed_multiplier 应恢复为 3.0")

	GameConfig.zoom_speed = original_zoom
	GameConfig.shift_speed_multiplier = original_shift
	GameConfig.save_game_settings()

	_cleanup_test_settings()
	GameConfig.unified_save_path = original_save_path

func _cleanup_test_settings() -> void:
	if FileAccess.file_exists("res://save/test_game_settings.cfg"):
		DirAccess.remove_absolute("res://save/test_game_settings.cfg")
	var tmp_path := "res://save/test_game_settings.cfg.tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)

func test_grid_config_constants() -> void:
	assert_eq(GameConfig.CELL_SIZE, 64, "cell_size 应为 64")
	assert_eq(GameConfig.BIG_CELL_SIZE, 10, "big_cell_size 应为 10")

func test_line_config_constants() -> void:
	assert_eq(GameConfig.THIN_LINE_WIDTH, 1.0, "thin_line_width 应为 1.0")
	assert_eq(GameConfig.THICK_LINE_WIDTH, 3.0, "thick_line_width 应为 3.0")

func test_color_config_constants() -> void:
	assert_ne(GameConfig.BACKGROUND_COLOR, Color.BLACK, "background_color 不应为纯黑")
	assert_ne(GameConfig.LINE_COLOR, Color.BLACK, "line_color 不应为纯黑")

func test_building_config_constants() -> void:
	assert_eq(GameConfig.BUILDING_SIZE, 60, "building_size 应为 60")
	assert_eq(GameConfig.BUILDING_BORDER, 2, "building_border 应为 2")

func test_default_game_settings() -> void:
	assert_eq(GameConfig.DEFAULT_ZOOM_SPEED, 0.2, "DEFAULT_ZOOM_SPEED 应为 0.2")
	assert_eq(GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER, 5.0, "DEFAULT_SHIFT_SPEED_MULTIPLIER 应为 5.0")

func test_save_version_constant() -> void:
	assert_eq(GameConfig.SAVE_VERSION, "1.0.0", "SAVE_VERSION 应为 '1.0.0'")

func test_selection_constants() -> void:
	assert_ne(GameConfig.SELECTION_HIGHLIGHT_COLOR, Color.BLACK, "selection_highlight_color 不应为纯黑")
	assert_ne(GameConfig.SELECTION_BORDER_COLOR, Color.BLACK, "selection_border_color 不应为纯黑")
	assert_eq(GameConfig.PASTE_GHOST_ALPHA, 0.45, "paste_ghost_alpha 应为 0.45")

func test_load_settings_invalid_type_fallback() -> void:
	var original_save_path: String = GameConfig.unified_save_path
	GameConfig.unified_save_path = "res://save/test_game_settings_invalid.cfg"
	_cleanup_invalid_test_settings()
	# 构造 .cfg [settings] section 含无效类型数据
	# zoom_speed / shift_speed_multiplier 均为 String（非法类型），应回退默认值
	# 注意：ConfigFile 会删除值为 null 的 key，故用 String 表达"无效类型"
	var invalid_data := {
		"version": "1.0.0",
		"zoom_speed": "invalid",
		"shift_speed_multiplier": "not_a_number",
	}
	FileIOHelper.write_cfg_section(
		GameConfig.unified_save_path,
		GameConfig.SECTION_SETTINGS,
		invalid_data,
		"TestGameConfig"
	)
	GameConfig.zoom_speed = GameConfig.DEFAULT_ZOOM_SPEED
	GameConfig.shift_speed_multiplier = GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER
	GameConfig.load_game_settings()
	assert_eq(GameConfig.zoom_speed, GameConfig.DEFAULT_ZOOM_SPEED, "无效 zoom_speed 应回退默认值")
	assert_eq(GameConfig.shift_speed_multiplier, GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER, "无效 shift_speed_multiplier 应回退默认值")
	_cleanup_invalid_test_settings()
	GameConfig.unified_save_path = original_save_path

func _cleanup_invalid_test_settings() -> void:
	if FileAccess.file_exists("res://save/test_game_settings_invalid.cfg"):
		DirAccess.remove_absolute("res://save/test_game_settings_invalid.cfg")
	var tmp_path := "res://save/test_game_settings_invalid.cfg.tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)


## 迁移测试：旧版多 JSON 存档应被合并迁移到单 .cfg 文件
## 验证：1) .cfg 被创建且含三个 section；2) 旧 .json 被重命名为 .json.bak
func test_migrate_legacy_json_to_cfg() -> void:
	var original_unified := GameConfig.unified_save_path
	var original_legacy_save := GameConfig.legacy_save_file_path
	var original_legacy_settings := GameConfig.legacy_game_settings_file_path
	var original_legacy_keybind := GameConfig.legacy_keybind_file_path

	GameConfig.unified_save_path = "res://save/test_migrate.cfg"
	GameConfig.legacy_save_file_path = "res://save/test_migrate_buildings.json"
	GameConfig.legacy_game_settings_file_path = "res://save/test_migrate_settings.json"
	GameConfig.legacy_keybind_file_path = "res://save/test_migrate_keybindings.json"

	_cleanup_migrate_test()

	# 构造三个旧 JSON 存档文件
	var buildings_data := {
		"version": "1.0.0",
		"essence": 50.0,
		"buildings": {"5,5": {"type": "type_02"}},
	}
	var settings_data := {
		"version": "1.0.0",
		"zoom_speed": 0.15,
		"shift_speed_multiplier": 3.0,
	}
	var keybind_data := {
		"version": "1.0.0",
		"keybindings": {"move_up": [{"type": "key", "keycode": 87.0}]},
	}
	FileIOHelper.write_json_file(GameConfig.legacy_save_file_path, buildings_data, "TestMigrate")
	FileIOHelper.write_json_file(GameConfig.legacy_game_settings_file_path, settings_data, "TestMigrate")
	FileIOHelper.write_json_file(GameConfig.legacy_keybind_file_path, keybind_data, "TestMigrate")

	# 触发迁移
	GameConfig._migrate_legacy_saves()

	# 验证 .cfg 被创建
	assert_true(FileAccess.file_exists(GameConfig.unified_save_path), "迁移后应创建 .cfg 文件")

	# 验证旧 .json 被重命名为 .json.bak
	assert_false(FileAccess.file_exists(GameConfig.legacy_save_file_path), "迁移后旧 buildings.json 应被重命名")
	assert_true(FileAccess.file_exists(GameConfig.legacy_save_file_path + ".bak"), "旧 buildings.json 应重命名为 .bak")
	assert_true(FileAccess.file_exists(GameConfig.legacy_game_settings_file_path + ".bak"), "旧 settings.json 应重命名为 .bak")
	assert_true(FileAccess.file_exists(GameConfig.legacy_keybind_file_path + ".bak"), "旧 keybindings.json 应重命名为 .bak")

	# 验证 .cfg 三个 section 内容正确
	var buildings_result := FileIOHelper.read_cfg_section(
		GameConfig.unified_save_path, GameConfig.SECTION_BUILDINGS, "TestMigrate"
	)
	assert_true(buildings_result.success, "应能读取 [buildings] section")
	assert_eq(buildings_result.data.get("essence", 0.0), 50.0, "essence 应正确迁移")

	var settings_result := FileIOHelper.read_cfg_section(
		GameConfig.unified_save_path, GameConfig.SECTION_SETTINGS, "TestMigrate"
	)
	assert_true(settings_result.success, "应能读取 [settings] section")
	assert_eq(settings_result.data.get("zoom_speed", 0.0), 0.15, "zoom_speed 应正确迁移")

	var keybind_result := FileIOHelper.read_cfg_section(
		GameConfig.unified_save_path, GameConfig.SECTION_KEYBINDINGS, "TestMigrate"
	)
	assert_true(keybind_result.success, "应能读取 [keybindings] section")
	assert_true(keybind_result.data.has("keybindings"), "keybindings 字段应迁移")

	_cleanup_migrate_test()
	GameConfig.unified_save_path = original_unified
	GameConfig.legacy_save_file_path = original_legacy_save
	GameConfig.legacy_game_settings_file_path = original_legacy_settings
	GameConfig.legacy_keybind_file_path = original_legacy_keybind


## 迁移测试：.cfg 已存在时不应触发迁移（跳过）
func test_migrate_skipped_when_cfg_exists() -> void:
	var original_unified := GameConfig.unified_save_path
	var original_legacy_save := GameConfig.legacy_save_file_path

	GameConfig.unified_save_path = "res://save/test_migrate_skip.cfg"
	GameConfig.legacy_save_file_path = "res://save/test_migrate_skip_buildings.json"

	_cleanup_migrate_skip_test()

	# 先创建 .cfg（含 [settings] section）
	FileIOHelper.write_cfg_section(
		GameConfig.unified_save_path, GameConfig.SECTION_SETTINGS,
		{"version": "1.0.0", "zoom_speed": 0.25}, "TestMigrate"
	)
	# 同时存在旧 .json（不应被迁移）
	FileIOHelper.write_json_file(
		GameConfig.legacy_save_file_path,
		{"version": "1.0.0", "essence": 99.0, "buildings": {}}, "TestMigrate"
	)

	# 调用迁移（应跳过，因为 .cfg 已存在）
	GameConfig._migrate_legacy_saves()

	# 验证旧 .json 仍存在（未被重命名）
	assert_true(FileAccess.file_exists(GameConfig.legacy_save_file_path), ".cfg 已存在时旧 .json 应保留不动")
	# 验证 [buildings] section 不存在（迁移未发生）
	assert_false(
		FileIOHelper.cfg_has_section(GameConfig.unified_save_path, GameConfig.SECTION_BUILDINGS),
		".cfg 已存在时不应写入 [buildings] section"
	)

	_cleanup_migrate_skip_test()
	GameConfig.unified_save_path = original_unified
	GameConfig.legacy_save_file_path = original_legacy_save


func _cleanup_migrate_test() -> void:
	for path: String in [
		GameConfig.unified_save_path,
		GameConfig.legacy_save_file_path,
		GameConfig.legacy_game_settings_file_path,
		GameConfig.legacy_keybind_file_path,
		GameConfig.legacy_save_file_path + ".bak",
		GameConfig.legacy_game_settings_file_path + ".bak",
		GameConfig.legacy_keybind_file_path + ".bak",
		GameConfig.unified_save_path + ".tmp",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _cleanup_migrate_skip_test() -> void:
	for path: String in [
		GameConfig.unified_save_path,
		GameConfig.legacy_save_file_path,
		GameConfig.legacy_save_file_path + ".bak",
		GameConfig.unified_save_path + ".tmp",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
