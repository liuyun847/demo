extends GutTest

func test_dir_4_has_four_directions():
	assert_eq(GridCoordinate.DIR_4.size(), 4, "DIR_4 应有 4 个方向")

func test_dir_4_values():
	assert_eq(GridCoordinate.DIR_4[0], Vector2i(0, -1), "索引0应为上")
	assert_eq(GridCoordinate.DIR_4[1], Vector2i(1, 0), "索引1应为右")
	assert_eq(GridCoordinate.DIR_4[2], Vector2i(0, 1), "索引2应为下")
	assert_eq(GridCoordinate.DIR_4[3], Vector2i(-1, 0), "索引3应为左")

func test_world_to_grid_origin():
	var result = GridCoordinate.world_to_grid(Vector2.ZERO)
	assert_eq(result, Vector2i.ZERO, "原点应映射到 (0, 0)")

func test_world_to_grid_positive():
	var result = GridCoordinate.world_to_grid(Vector2(100, 150))
	assert_eq(result, Vector2i(1, 2), "(100, 150) 应映射到 (1, 2)")

func test_world_to_grid_negative():
	var result = GridCoordinate.world_to_grid(Vector2(-10, -70))
	assert_eq(result, Vector2i(-1, -2), "负坐标应向下取整")

func test_world_to_grid_boundary():
	var result = GridCoordinate.world_to_grid(Vector2(GameConfig.cell_size - 1, GameConfig.cell_size - 1))
	assert_eq(result, Vector2i(0, 0), "边界内一点应仍属于 (0, 0)")

func test_world_to_grid_exact():
	var result = GridCoordinate.world_to_grid(Vector2(GameConfig.cell_size, GameConfig.cell_size))
	assert_eq(result, Vector2i(1, 1), "恰好到达边界应映射到 (1, 1)")

func test_grid_to_world_basic():
	var result = GridCoordinate.grid_to_world(Vector2i(0, 0))
	var half_size = GameConfig.building_size / 2.0
	var expected_x = GameConfig.building_border + half_size
	var expected_y = GameConfig.building_border + half_size
	assert_eq(result, Vector2(expected_x, expected_y), "(0, 0) 应映射到正确的世界坐标")

func test_grid_to_world_positive():
	var result = GridCoordinate.grid_to_world(Vector2i(2, 3))
	var half_size = GameConfig.building_size / 2.0
	var expected_x = 2 * GameConfig.cell_size + GameConfig.building_border + half_size
	var expected_y = 3 * GameConfig.cell_size + GameConfig.building_border + half_size
	assert_eq(result, Vector2(expected_x, expected_y), "(2, 3) 应映射到正确的世界坐标")

func test_grid_to_world_negative():
	var result = GridCoordinate.grid_to_world(Vector2i(-1, -2))
	var half_size = GameConfig.building_size / 2.0
	var expected_x = -1 * GameConfig.cell_size + GameConfig.building_border + half_size
	var expected_y = -2 * GameConfig.cell_size + GameConfig.building_border + half_size
	assert_eq(result, Vector2(expected_x, expected_y), "负网格坐标应映射到正确的世界坐标")

func test_world_to_grid_roundtrip():
	var original = Vector2i(5, 7)
	var world = GridCoordinate.grid_to_world(original)
	var roundtrip = GridCoordinate.world_to_grid(world)
	assert_eq(roundtrip, original, "网格坐标 -> 世界坐标 -> 网格坐标 应保持不变")
