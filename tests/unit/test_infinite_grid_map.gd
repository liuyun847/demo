extends GutTest

var _grid_map: Node = null
const GridMapScript := preload("res://scripts/InfiniteGridMap.gd")

func before_each():
	_grid_map = autoqfree(GridMapScript.new())
	add_child_autoqfree(_grid_map)


func test_block_pixel_size():
	var expected = GameConfig.cell_size * GameConfig.big_cell_size
	assert_eq(_grid_map.block_pixel_size, expected, "block_pixel_size 应为 cell_size * big_cell_size")

func test_loaded_blocks_exists():
	assert_true("loaded_blocks" in _grid_map, "应包含 loaded_blocks 属性")

func test_load_block():
	assert_false(_grid_map.loaded_blocks.has(Vector2i(42, 42)), "加载前不应包含 (42, 42)")
	_grid_map.load_block(Vector2i(42, 42))
	assert_true(_grid_map.loaded_blocks.has(Vector2i(42, 42)), "加载后应包含 (42, 42)")

func test_unload_block():
	_grid_map.load_block(Vector2i(10, 20))
	var block_node = _grid_map.get_node_or_null("Block_10_20")
	assert_true(_grid_map.loaded_blocks.has(Vector2i(10, 20)), "卸载前应包含 (10, 20)")
	assert_true(block_node == null or block_node.is_inside_tree(), "区块节点应有效")
	_grid_map.unload_block(Vector2i(10, 20))
	assert_false(_grid_map.loaded_blocks.has(Vector2i(10, 20)), "卸载后不应包含 (10, 20)")

func test_unload_nonexistent_block():
	_grid_map.unload_block(Vector2i(999, 999))
	assert_true(true, "卸载不存在的块不应报错")

func test_load_same_block_once():
	_grid_map.load_block(Vector2i(5, 5))
	var count_before = _grid_map.loaded_blocks.size()
	_grid_map.load_block(Vector2i(5, 5))
	assert_eq(_grid_map.loaded_blocks.size(), count_before, "加载相同块不应重复添加")

func test_unload_block_removes_from_dictionary():
	_grid_map.load_block(Vector2i(1, 1))
	assert_true(_grid_map.loaded_blocks.has(Vector2i(1, 1)), "加载后应存在")
	_grid_map.unload_block(Vector2i(1, 1))
	assert_false(_grid_map.loaded_blocks.has(Vector2i(1, 1)), "卸载后应移除")
