extends GutTest

var _grid: ElementGrid = null

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())

func after_each() -> void:
	_grid = null

func _create_element(element_type_id: String) -> ElementData:
	var element := ElementData.new()
	element.element_type = ElementRegistry.get_element_type(element_type_id)
	return element

func test_set_element_empty_position() -> void:
	var element := _create_element("water")
	var result: bool = _grid.set_element(Vector2i(0, 0), element)
	assert_true(result, "在空格子放置元素应成功")
	assert_true(_grid.has_element(Vector2i(0, 0)), "该格子应有元素")

func test_set_element_occupied_position() -> void:
	var element1 := _create_element("water")
	_grid.set_element(Vector2i(0, 0), element1)

	var element2 := _create_element("fire")
	var result: bool = _grid.set_element(Vector2i(0, 0), element2)
	assert_false(result, "在已有元素的格子放置元素应失败")

func test_remove_element() -> void:
	var element := _create_element("water")
	_grid.set_element(Vector2i(0, 0), element)

	var removed: ElementData = _grid.remove_element(Vector2i(0, 0))
	assert_not_null(removed, "移除元素应返回被移除的元素")
	assert_false(_grid.has_element(Vector2i(0, 0)), "移除后格子应为空")

func test_remove_nonexistent_element() -> void:
	var removed: ElementData = _grid.remove_element(Vector2i(99, 99))
	assert_null(removed, "移除不存在的元素应返回 null")

func test_get_element() -> void:
	var element := _create_element("fire")
	_grid.set_element(Vector2i(5, 3), element)

	var retrieved: ElementData = _grid.get_element(Vector2i(5, 3))
	assert_not_null(retrieved, "应能获取已放置的元素")
	assert_eq(retrieved.element_type.element_id, "fire", "获取的元素类型应正确")

func test_get_nonexistent_element() -> void:
	var retrieved: ElementData = _grid.get_element(Vector2i(0, 0))
	assert_null(retrieved, "获取不存在的元素应返回 null")

func test_is_position_available_empty() -> void:
	assert_true(_grid.is_position_available(Vector2i(5, 5)), "空格子应可用")

func test_is_position_available_with_element() -> void:
	var element := _create_element("water")
	_grid.set_element(Vector2i(3, 3), element)
	assert_false(_grid.is_position_available(Vector2i(3, 3)), "有元素的格子应不可用")

func test_get_all_element_positions() -> void:
	var element1 := _create_element("water")
	var element2 := _create_element("fire")
	_grid.set_element(Vector2i(0, 0), element1)
	_grid.set_element(Vector2i(1, 1), element2)

	var positions: Array[Vector2i] = _grid.get_all_element_positions()
	assert_eq(positions.size(), 2, "应有 2 个元素位置")

func test_clear_all() -> void:
	var element1 := _create_element("water")
	var element2 := _create_element("fire")
	_grid.set_element(Vector2i(0, 0), element1)
	_grid.set_element(Vector2i(1, 1), element2)

	_grid.clear_all()
	assert_eq(_grid.get_all_element_positions().size(), 0, "清空后应无元素")
