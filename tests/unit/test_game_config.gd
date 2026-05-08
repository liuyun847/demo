extends GutTest

func test_building_type_constants():
	assert_eq(GameConfig.container_type_id, "type_01", "container_type_id 应为 type_01")
	assert_eq(GameConfig.pipe_type_id, "type_02", "pipe_type_id 应为 type_02")
	assert_eq(GameConfig.water_source_type_id, "type_03", "water_source_type_id 应为 type_03")

func test_fluid_config_constants():
	assert_eq(GameConfig.fluid_tick_interval, 0.3, "fluid_tick_interval 应为 0.3")
	assert_eq(GameConfig.fluid_sub_iterations, 5, "fluid_sub_iterations 应为 5")
	assert_eq(GameConfig.fluid_flow_rate, 0.3, "fluid_flow_rate 应为 0.3")

func test_block_pixel_size():
	var expected = GameConfig.cell_size * GameConfig.big_cell_size
	assert_eq(GameConfig.get_block_pixel_size(), expected, "get_block_pixel_size 应为 cell_size * big_cell_size")

func test_save_and_load_settings():
	var original_zoom = GameConfig.zoom_speed
	var original_shift = GameConfig.shift_speed_multiplier

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
