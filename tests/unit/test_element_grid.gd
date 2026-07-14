extends GutTest

var _grid: ElementGrid = null

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())

func after_each() -> void:
	_grid = null

func test_set_element_empty_position() -> void:
	var result: bool = _grid.set_element(Vector2i(0, 0), "water", 0)
	assert_true(result, "在空格子放置元素应成功")
	assert_true(_grid.has_element(Vector2i(0, 0)), "该格子应有元素")

func test_set_element_occupied_position() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	var result: bool = _grid.set_element(Vector2i(0, 0), "water", 0)
	assert_false(result, "在已有元素的格子放置元素应失败")

func test_set_element_stores_source_y() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 5)
	assert_eq(_grid.get_source_y(Vector2i(0, 0)), 5, "source_y 应正确存储")

func test_remove_element() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.remove_element(Vector2i(0, 0))
	assert_false(_grid.has_element(Vector2i(0, 0)), "移除后格子应为空")

func test_remove_nonexistent_element() -> void:
	_grid.remove_element(Vector2i(99, 99))
	assert_false(_grid.has_element(Vector2i(99, 99)), "不存在的位置，has_element 应返回 false")

func test_move_element() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 5)
	var result: bool = _grid.move_element(Vector2i(0, 0), Vector2i(1, 0))
	assert_true(result, "移动元素应成功")
	assert_false(_grid.has_element(Vector2i(0, 0)), "原位置应无元素")
	assert_true(_grid.has_element(Vector2i(1, 0)), "目标位置应有元素")
	assert_eq(_grid.get_source_y(Vector2i(1, 0)), 5, "目标位置应继承 source_y")

func test_move_element_to_occupied() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.set_element(Vector2i(1, 0), "water", 0)
	var result: bool = _grid.move_element(Vector2i(0, 0), Vector2i(1, 0))
	assert_false(result, "移动到有元素的位置应失败")

func test_is_position_available_empty() -> void:
	assert_true(_grid.is_position_available(Vector2i(5, 5)), "空格子应可用")

func test_is_position_available_with_element() -> void:
	_grid.set_element(Vector2i(3, 3), "water", 0)
	assert_false(_grid.is_position_available(Vector2i(3, 3)), "有元素的格子应不可用")

func test_get_all_element_positions() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.set_element(Vector2i(1, 1), "water", 0)

	var positions: Array[Vector2i] = _grid.get_all_element_positions()
	assert_eq(positions.size(), 2, "应有 2 个元素位置")

func test_clear_all() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.set_element(Vector2i(1, 1), "water", 0)

	_grid.clear_all()
	assert_eq(_grid.get_all_element_positions().size(), 0, "清空后应无元素")
