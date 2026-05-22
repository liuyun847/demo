extends GutTest

func test_building_type_constants() -> void:
	assert_eq(GameConfig.container_type_id, "type_01", "container_type_id 应为 type_01")
	assert_eq(GameConfig.pipe_type_id, "type_02", "pipe_type_id 应为 type_02")

func test_fluid_config_constants() -> void:
	assert_eq(GameConfig.reaction_tick_interval, 0.3, "reaction_tick_interval 应为 0.3")

func test_block_pixel_size() -> void:
	var expected: int = GameConfig.cell_size * GameConfig.big_cell_size
	assert_eq(GameConfig.get_block_pixel_size(), expected, "get_block_pixel_size 应为 cell_size * big_cell_size")

func test_save_and_load_settings() -> void:
	var original_save_path: String = GameConfig.game_settings_file_path
	GameConfig.game_settings_file_path = "res://save/test_game_settings.json"

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
	GameConfig.game_settings_file_path = original_save_path

func _cleanup_test_settings() -> void:
	if FileAccess.file_exists("res://save/test_game_settings.json"):
		DirAccess.remove_absolute("res://save/test_game_settings.json")

func test_grid_config_constants() -> void:
	assert_eq(GameConfig.cell_size, 64, "cell_size 应为 64")
	assert_eq(GameConfig.big_cell_size, 10, "big_cell_size 应为 10")

func test_line_config_constants() -> void:
	assert_eq(GameConfig.thin_line_width, 1.0, "thin_line_width 应为 1.0")
	assert_eq(GameConfig.thick_line_width, 3.0, "thick_line_width 应为 3.0")

func test_color_config_constants() -> void:
	assert_ne(GameConfig.background_color, Color.BLACK, "background_color 不应为纯黑")
	assert_ne(GameConfig.line_color, Color.BLACK, "line_color 不应为纯黑")

func test_building_config_constants() -> void:
	assert_eq(GameConfig.building_size, 60, "building_size 应为 60")
	assert_eq(GameConfig.building_border, 2, "building_border 应为 2")

func test_default_game_settings() -> void:
	assert_eq(GameConfig.DEFAULT_ZOOM_SPEED, 0.2, "DEFAULT_ZOOM_SPEED 应为 0.2")
	assert_eq(GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER, 5.0, "DEFAULT_SHIFT_SPEED_MULTIPLIER 应为 5.0")

func test_save_version_constant() -> void:
	assert_eq(GameConfig.SAVE_VERSION, "1.0.0", "SAVE_VERSION 应为 '1.0.0'")

func test_selection_constants() -> void:
	assert_ne(GameConfig.selection_highlight_color, Color.BLACK, "selection_highlight_color 不应为纯黑")
	assert_ne(GameConfig.selection_border_color, Color.BLACK, "selection_border_color 不应为纯黑")
	assert_eq(GameConfig.paste_ghost_alpha, 0.45, "paste_ghost_alpha 应为 0.45")

func test_load_settings_invalid_type_fallback() -> void:
	var original_save_path: String = GameConfig.game_settings_file_path
	GameConfig.game_settings_file_path = "res://save/test_game_settings_invalid.json"
	_cleanup_invalid_test_settings()
	var file := FileAccess.open("res://save/test_game_settings_invalid.json", FileAccess.WRITE)
	if file:
		file.store_string('{"version":"1.0.0","zoom_speed":"invalid","shift_speed_multiplier":null}')
		file.close()
	GameConfig.zoom_speed = GameConfig.DEFAULT_ZOOM_SPEED
	GameConfig.shift_speed_multiplier = GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER
	GameConfig.load_game_settings()
	assert_eq(GameConfig.zoom_speed, GameConfig.DEFAULT_ZOOM_SPEED, "无效 zoom_speed 应回退默认值")
	assert_eq(GameConfig.shift_speed_multiplier, GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER, "无效 shift_speed_multiplier 应回退默认值")
	_cleanup_invalid_test_settings()
	GameConfig.game_settings_file_path = original_save_path

func _cleanup_invalid_test_settings() -> void:
	if FileAccess.file_exists("res://save/test_game_settings_invalid.json"):
		DirAccess.remove_absolute("res://save/test_game_settings_invalid.json")
