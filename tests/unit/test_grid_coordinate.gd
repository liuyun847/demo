extends GutTest

func test_dir_4_has_four_directions() -> void:
	assert_eq(GridCoordinate.DIR_4.size(), 4, "DIR_4 应有 4 个方向")

func test_dir_4_values() -> void:
	assert_eq(GridCoordinate.DIR_4[0], Vector2i(0, -1), "索引0应为上")
	assert_eq(GridCoordinate.DIR_4[1], Vector2i(1, 0), "索引1应为右")
	assert_eq(GridCoordinate.DIR_4[2], Vector2i(0, 1), "索引2应为下")
	assert_eq(GridCoordinate.DIR_4[3], Vector2i(-1, 0), "索引3应为左")

func test_world_to_grid_origin() -> void:
	var result: Vector2i = GridCoordinate.world_to_grid(Vector2.ZERO)
	assert_eq(result, Vector2i.ZERO, "原点应映射到 (0, 0)")

func test_world_to_grid_positive() -> void:
	var result: Vector2i = GridCoordinate.world_to_grid(Vector2(100, 150))
	assert_eq(result, Vector2i(1, 2), "(100, 150) 应映射到 (1, 2)")

func test_world_to_grid_negative() -> void:
	var result: Vector2i = GridCoordinate.world_to_grid(Vector2(-10, -70))
	assert_eq(result, Vector2i(-1, -2), "负坐标应向下取整")

func test_world_to_grid_boundary() -> void:
	var result: Vector2i = GridCoordinate.world_to_grid(Vector2(GameConfig.cell_size - 1, GameConfig.cell_size - 1))
	assert_eq(result, Vector2i(0, 0), "边界内一点应仍属于 (0, 0)")

func test_world_to_grid_exact() -> void:
	var result: Vector2i = GridCoordinate.world_to_grid(Vector2(GameConfig.cell_size, GameConfig.cell_size))
	assert_eq(result, Vector2i(1, 1), "恰好到达边界应映射到 (1, 1)")

func test_grid_to_world_basic() -> void:
	var result: Vector2 = GridCoordinate.grid_to_world(Vector2i(0, 0))
	var half_size: float = GameConfig.building_size / 2.0
	var expected_x: float = GameConfig.building_border + half_size
	var expected_y: float = GameConfig.building_border + half_size
	assert_eq(result, Vector2(expected_x, expected_y), "(0, 0) 应映射到正确的世界坐标")

func test_grid_to_world_positive() -> void:
	var result: Vector2 = GridCoordinate.grid_to_world(Vector2i(2, 3))
	var half_size: float = GameConfig.building_size / 2.0
	var expected_x: float = 2 * GameConfig.cell_size + GameConfig.building_border + half_size
	var expected_y: float = 3 * GameConfig.cell_size + GameConfig.building_border + half_size
	assert_eq(result, Vector2(expected_x, expected_y), "(2, 3) 应映射到正确的世界坐标")

func test_grid_to_world_negative() -> void:
	var result: Vector2 = GridCoordinate.grid_to_world(Vector2i(-1, -2))
	var half_size: float = GameConfig.building_size / 2.0
	var expected_x: float = -1 * GameConfig.cell_size + GameConfig.building_border + half_size
	var expected_y: float = -2 * GameConfig.cell_size + GameConfig.building_border + half_size
	assert_eq(result, Vector2(expected_x, expected_y), "负网格坐标应映射到正确的世界坐标")

func test_world_to_grid_roundtrip() -> void:
	var original: Vector2i = Vector2i(5, 7)
	var world: Vector2 = GridCoordinate.grid_to_world(original)
	var roundtrip: Vector2i = GridCoordinate.world_to_grid(world)
	assert_eq(roundtrip, original, "网格坐标 -> 世界坐标 -> 网格坐标 应保持不变")

func test_screen_to_world_zoom_1() -> void:
	var camera: Camera2D = autoqfree(Camera2D.new())
	add_child_autoqfree(camera)
	camera.global_position = Vector2(200, 300)
	camera.zoom = Vector2(1, 1)
	var viewport: Viewport = camera.get_viewport()
	var view_size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = view_size / 2.0
	var result: Vector2 = GridCoordinate.screen_to_world(camera, center)
	assert_eq(result, camera.global_position, "缩放1倍时屏幕中心应映射到相机位置")

func test_screen_to_world_zoom_2() -> void:
	var camera: Camera2D = autoqfree(Camera2D.new())
	add_child_autoqfree(camera)
	camera.global_position = Vector2(500, 400)
	camera.zoom = Vector2(2, 2)
	var viewport: Viewport = camera.get_viewport()
	var view_size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = view_size / 2.0
	var screen_pos: Vector2 = center + Vector2(100, 50)
	var offset: Vector2 = Vector2(100, 50) / camera.zoom
	var result: Vector2 = GridCoordinate.screen_to_world(camera, screen_pos)
	assert_eq(result, camera.global_position + offset, "缩放2倍时屏幕偏移应正确映射到世界坐标")

func test_screen_to_world_corner() -> void:
	var camera: Camera2D = autoqfree(Camera2D.new())
	add_child_autoqfree(camera)
	camera.global_position = Vector2(100, 100)
	camera.zoom = Vector2(1, 1)
	var viewport: Viewport = camera.get_viewport()
	var view_size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = view_size / 2.0
	var result: Vector2 = GridCoordinate.screen_to_world(camera, Vector2.ZERO)
	var expected: Vector2 = (Vector2.ZERO - center) + camera.global_position
	assert_eq(result, expected, "屏幕左上角应映射到正确的世界坐标")
