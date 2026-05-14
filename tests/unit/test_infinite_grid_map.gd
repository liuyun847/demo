extends GutTest

var _grid_map: Node = null
const GridMapScript: GDScript = preload("res://scripts/InfiniteGridMap.gd")

func before_each() -> void:
	_grid_map = autoqfree(GridMapScript.new())
	add_child_autoqfree(_grid_map)


func test_block_pixel_size() -> void:
	var expected: int = GameConfig.cell_size * GameConfig.big_cell_size
	assert_eq(_grid_map.block_pixel_size, expected, "block_pixel_size 应为 cell_size * big_cell_size")

func test_loaded_blocks_exists() -> void:
	assert_true("loaded_blocks" in _grid_map, "应包含 loaded_blocks 属性")

func test_load_block() -> void:
	assert_false(_grid_map.loaded_blocks.has(Vector2i(42, 42)), "加载前不应包含 (42, 42)")
	_grid_map.mark_block_visible(Vector2i(42, 42))
	assert_true(_grid_map.loaded_blocks.has(Vector2i(42, 42)), "加载后应包含 (42, 42)")

func test_unload_block() -> void:
	_grid_map.mark_block_visible(Vector2i(10, 20))
	assert_true(_grid_map.loaded_blocks.has(Vector2i(10, 20)), "卸载前应包含 (10, 20)")
	_grid_map.mark_block_hidden(Vector2i(10, 20))
	assert_false(_grid_map.loaded_blocks.has(Vector2i(10, 20)), "卸载后不应包含 (10, 20)")

func test_unload_nonexistent_block() -> void:
	_grid_map.mark_block_hidden(Vector2i(999, 999))
	assert_true(true, "卸载不存在的块不应报错")

func test_load_same_block_once() -> void:
	_grid_map.mark_block_visible(Vector2i(5, 5))
	var count_before: int = _grid_map.loaded_blocks.size()
	_grid_map.mark_block_visible(Vector2i(5, 5))
	assert_eq(_grid_map.loaded_blocks.size(), count_before, "加载相同块不应重复添加")

func test_unload_block_removes_from_dictionary() -> void:
	_grid_map.mark_block_visible(Vector2i(1, 1))
	assert_true(_grid_map.loaded_blocks.has(Vector2i(1, 1)), "加载后应存在")
	_grid_map.mark_block_hidden(Vector2i(1, 1))
	assert_false(_grid_map.loaded_blocks.has(Vector2i(1, 1)), "卸载后应移除")

func test_get_visible_block_range_returns_dict() -> void:
	var result: Dictionary = _grid_map.get_visible_block_range()
	assert_has(result, "start_x", "返回值应包含 start_x")
	assert_has(result, "end_x", "返回值应包含 end_x")
	assert_has(result, "start_y", "返回值应包含 start_y")
	assert_has(result, "end_y", "返回值应包含 end_y")

func test_visible_range_keys_have_correct_types() -> void:
	var result: Dictionary = _grid_map.get_visible_block_range()
	assert_true(result.start_x is int, "start_x 应为 int")
	assert_true(result.end_x is int, "end_x 应为 int")
	assert_true(result.start_y is int, "start_y 应为 int")
	assert_true(result.end_y is int, "end_y 应为 int")

func test_update_visible_blocks_loads_blocks() -> void:
	_grid_map.loaded_blocks.clear()
	_grid_map.update_visible_blocks()
	assert_true(_grid_map.loaded_blocks.size() > 0, "update_visible_blocks 后 loaded_blocks 应非空")

func test_get_visible_block_range_no_camera() -> void:
	var original_camera: Camera2D = _grid_map.get_viewport().get_camera_2d()
	if original_camera:
		original_camera.enabled = false
	var result: Dictionary = _grid_map.get_visible_block_range()
	assert_eq(result.start_x, 0, "无相机时 start_x 应为 0")
	assert_eq(result.end_x, 0, "无相机时 end_x 应为 0")
	assert_eq(result.start_y, 0, "无相机时 start_y 应为 0")
	assert_eq(result.end_y, 0, "无相机时 end_y 应为 0")
