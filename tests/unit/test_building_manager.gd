extends GutTest

var _bm = null

func before_each():
	if _bm == null:
		load("res://scripts/building/fluid_node_base.gd")
		load("res://scripts/building/container_node.gd")
		load("res://scripts/building/pipe_node.gd")
		load("res://scripts/building/water_source_node.gd")
		load("res://scripts/resources/building_data.gd")
	_bm = autoqfree(load("res://scripts/building/building_manager.gd").new())
	add_child_autoqfree(_bm)
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

func test_has_building_empty():
	assert_false(_bm.has_building(Vector2i(0, 0)), "刚创建时不应有建筑")

func test_place_building():
	var result = _bm.place_building(Vector2i(0, 0), "type_01")
	assert_true(result, "放置应成功")
	assert_true(_bm.has_building(Vector2i(0, 0)), "放置后该位置应有建筑")

func test_place_building_on_occupied():
	_bm.place_building(Vector2i(5, 5), "type_01")
	var result = _bm.place_building(Vector2i(5, 5), "type_02")
	assert_false(result, "已占用位置不应能重复放置")

func test_place_building_returns_false_when_occupied():
	_bm.place_building(Vector2i(3, 3), "type_01")
	assert_false(_bm.place_building(Vector2i(3, 3), "type_01"))

func test_place_building_container_type():
	var result = _bm.place_building(Vector2i(1, 2), "type_01")
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(1, 2)))

func test_place_building_pipe_type():
	var result = _bm.place_building(Vector2i(4, 1), "type_02")
	assert_true(result)

func test_place_building_water_source_type():
	var result = _bm.place_building(Vector2i(0, 3), "type_03")
	assert_true(result)

func test_place_building_default_type():
	var result = _bm.place_building(Vector2i(7, 7), "default")
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(7, 7)))

func test_remove_building():
	_bm.place_building(Vector2i(2, 2), "type_01")
	var removed = _bm.remove_building(Vector2i(2, 2))
	assert_true(removed, "删除应成功")
	assert_false(_bm.has_building(Vector2i(2, 2)), "删除后该位置不应有建筑")

func test_remove_nonexistent_building():
	var removed = _bm.remove_building(Vector2i(99, 99))
	assert_false(removed, "删除不存在的建筑应返回 false")

func test_get_all_buildings_data():
	_bm.place_building(Vector2i(0, 0), "type_01")
	_bm.place_building(Vector2i(1, 0), "type_02")
	var data = _bm.get_all_buildings_data()
	assert_eq(data.size(), 2, "应有 2 个建筑记录")
	assert_true(data.has(Vector2i(0, 0)), "应包含 (0, 0)")
	assert_true(data.has(Vector2i(1, 0)), "应包含 (1, 0)")

func test_get_all_buildings_data_isolation():
	_bm.place_building(Vector2i(0, 0), "type_01")
	var data = _bm.get_all_buildings_data()
	data.erase(Vector2i(0, 0))
	assert_true(_bm.has_building(Vector2i(0, 0)), "副本的修改不应影响原数据")

func test_clear_all_buildings():
	_bm.place_building(Vector2i(0, 0), "type_01")
	_bm.place_building(Vector2i(1, 1), "type_02")
	_bm.place_building(Vector2i(2, 2), "type_03")
	_bm.clear_all_buildings()
	assert_eq(_bm.get_all_buildings_data().size(), 0, "清除后应无建筑")

func test_get_line_cells_horizontal():
	var cells = _bm.get_line_cells(Vector2i(0, 5), Vector2i(4, 5))
	assert_eq(cells.size(), 5, "水平线上应有 5 个格子")
	assert_eq(cells[0], Vector2i(0, 5))
	assert_eq(cells[4], Vector2i(4, 5))

func test_get_line_cells_vertical():
	var cells = _bm.get_line_cells(Vector2i(3, 0), Vector2i(3, 3))
	assert_eq(cells.size(), 4, "垂直线上应有 4 个格子")
	assert_eq(cells[0], Vector2i(3, 0))
	assert_eq(cells[3], Vector2i(3, 3))

func test_get_line_cells_reverse():
	var cells = _bm.get_line_cells(Vector2i(4, 5), Vector2i(0, 5))
	assert_eq(cells.size(), 5, "反向水平线也应有 5 个格子")

func test_get_line_cells_single_point():
	var cells = _bm.get_line_cells(Vector2i(2, 2), Vector2i(2, 2))
	assert_eq(cells.size(), 1, "单点应返回 1 个格子")
	assert_eq(cells[0], Vector2i(2, 2))

func test_get_rect_cells():
	var cells = _bm.get_rect_cells(Vector2i(1, 1), Vector2i(3, 3))
	assert_eq(cells.size(), 9, "3x3 矩形应有 9 个格子")

func test_get_rect_cells_single():
	var cells = _bm.get_rect_cells(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(cells.size(), 1, "单点矩形应返回 1 个格子")

func test_get_rect_cells_reverse():
	var cells = _bm.get_rect_cells(Vector2i(3, 3), Vector2i(1, 1))
	assert_eq(cells.size(), 9, "反向矩形也应有 9 个格子")

func test_place_buildings_in_line():
	var cells = _bm.get_line_cells(Vector2i(0, 0), Vector2i(4, 0))
	var placed = _bm.place_buildings_in_line(cells, "type_02")
	assert_eq(placed, 5, "应成功放置 5 个建筑")
	for i in range(5):
		assert_true(_bm.has_building(Vector2i(i, 0)))

func test_remove_buildings_in_rect():
	for x in range(3):
		for y in range(3):
			_bm.place_building(Vector2i(x, y), "type_01")
	var cells = _bm.get_rect_cells(Vector2i(0, 0), Vector2i(2, 2))
	var removed = _bm.remove_buildings_in_rect(cells)
	assert_eq(removed, 9, "应成功删除 9 个建筑")

func test_ghost_show_and_hide():
	_bm.show_ghost(Array[Vector2i]([Vector2i(0, 0), Vector2i(1, 1)]))
	assert_eq(_bm.ghost_cells.size(), 2, "ghost_cells 应有 2 个格子")
	_bm.hide_ghost()
	assert_true(_bm.ghost_cells.is_empty(), "隐藏后应为空")

func test_remove_ghost_show_and_hide():
	_bm.show_remove_ghost(Array[Vector2i]([Vector2i(2, 2), Vector2i(3, 3)]))
	assert_eq(_bm.remove_ghost_cells.size(), 2)
	_bm.hide_remove_ghost()
	assert_true(_bm.remove_ghost_cells.is_empty())

func test_get_buildings_in_cells():
	_bm.place_building(Vector2i(0, 0), "type_01")
	_bm.place_building(Vector2i(0, 1), "type_02")
	var result = _bm.get_buildings_in_cells(Array[Vector2i]([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]))
	assert_eq(result.size(), 2, "应在 3 个格子中找到 2 个建筑")
