extends GutTest

const _BM = preload("res://scripts/building/building_manager.gd")

var _bm = null

func before_each():
	if _bm == null:
		preload("res://scripts/building/fluid_node_base.gd")
		preload("res://scripts/building/container_node.gd")
		preload("res://scripts/building/pipe_node.gd")
		preload("res://scripts/building/water_source_node.gd")
		preload("res://scripts/resources/building_data.gd")
	_bm = autoqfree(_BM.new())
	add_child_autoqfree(_bm)
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

func test_has_building_empty():
	assert_false(_bm.has_building(Vector2i(0, 0)), "刚创建时不应有建筑")

func test_place_building():
	var result = _bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	assert_true(result, "放置应成功")
	assert_true(_bm.has_building(Vector2i(0, 0)), "放置后该位置应有建筑")

func test_place_building_on_occupied():
	_bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	var result = _bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	assert_false(result, "已占用位置不应能重复放置")

func test_place_building_returns_false_when_occupied():
	_bm.place_building(Vector2i(3, 3), GameConfig.container_type_id)
	assert_false(_bm.place_building(Vector2i(3, 3), GameConfig.container_type_id))

func test_place_building_container_type():
	var result = _bm.place_building(Vector2i(1, 2), GameConfig.container_type_id)
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(1, 2)))

func test_place_building_pipe_type():
	var result = _bm.place_building(Vector2i(4, 1), GameConfig.pipe_type_id)
	assert_true(result)

func test_place_building_water_source_type():
	var result = _bm.place_building(Vector2i(0, 3), GameConfig.water_source_type_id)
	assert_true(result)

func test_place_building_default_type():
	var result = _bm.place_building(Vector2i(7, 7), "default")
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(7, 7)))

func test_remove_building():
	_bm.place_building(Vector2i(2, 2), GameConfig.container_type_id)
	var removed = _bm.remove_building(Vector2i(2, 2))
	assert_true(removed, "删除应成功")
	assert_false(_bm.has_building(Vector2i(2, 2)), "删除后该位置不应有建筑")

func test_remove_nonexistent_building():
	var removed = _bm.remove_building(Vector2i(99, 99))
	assert_false(removed, "删除不存在的建筑应返回 false")

func test_get_all_buildings_data():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	var data = _bm.get_all_buildings_data()
	assert_eq(data.size(), 2, "应有 2 个建筑记录")
	assert_true(data.has(Vector2i(0, 0)), "应包含 (0, 0)")
	assert_true(data.has(Vector2i(1, 0)), "应包含 (1, 0)")

func test_get_all_buildings_data_isolation():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var data = _bm.get_all_buildings_data()
	data.erase(Vector2i(0, 0))
	assert_true(_bm.has_building(Vector2i(0, 0)), "副本的修改不应影响原数据")

func test_clear_all_buildings():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 2), GameConfig.water_source_type_id)
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
	var placed = _bm.place_buildings_in_line(cells, GameConfig.pipe_type_id)
	assert_eq(placed, 5, "应成功放置 5 个建筑")
	for i in range(5):
		assert_true(_bm.has_building(Vector2i(i, 0)))

func test_remove_buildings_in_rect():
	for x in range(3):
		for y in range(3):
			_bm.place_building(Vector2i(x, y), GameConfig.container_type_id)
	var cells = _bm.get_rect_cells(Vector2i(0, 0), Vector2i(2, 2))
	var removed = _bm.remove_buildings_in_rect(cells)
	assert_eq(removed, 9, "应成功删除 9 个建筑")

func test_ghost_show_and_hide():
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	_bm.show_ghost(cells)
	assert_eq(_bm.ghost_cells.size(), 2, "ghost_cells 应有 2 个格子")
	_bm.hide_ghost()
	assert_true(_bm.ghost_cells.is_empty(), "隐藏后应为空")

func test_remove_ghost_show_and_hide():
	var cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 3)]
	_bm.show_remove_ghost(cells)
	assert_eq(_bm.remove_ghost_cells.size(), 2)
	_bm.hide_remove_ghost()
	assert_true(_bm.remove_ghost_cells.is_empty())

func test_get_buildings_in_cells():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.pipe_type_id)
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var result = _bm.get_buildings_in_cells(cells)
	assert_eq(result.size(), 2, "应在 3 个格子中找到 2 个建筑")

func test_get_building_type():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	assert_eq(_bm.get_building_type(Vector2i(0, 0)), GameConfig.container_type_id, "应返回正确的建筑类型")
	assert_eq(_bm.get_building_type(Vector2i(99, 99)), "", "不存在的位置应返回空字符串")

func test_get_building_data():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var data = _bm.get_building_data(Vector2i(0, 0))
	assert_not_null(data, "存在的位置应返回 BuildingData")
	if data:
		assert_eq(data.building_type, GameConfig.container_type_id, "building_type 应正确")
	assert_null(_bm.get_building_data(Vector2i(99, 99)), "不存在的位置应返回 null")

func test_set_selected_cells():
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2)]
	_bm.set_selected_cells(cells)
	assert_eq(_bm.selected_cells.size(), 2, "selected_cells 应有 2 个格子")
	assert_eq(_bm.selected_cells[0], Vector2i(1, 1))
	var empty: Array[Vector2i] = []
	_bm.set_selected_cells(empty)
	assert_true(_bm.selected_cells.is_empty(), "空数组应清空 selected_cells")

func test_set_paste_preview():
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	_bm.set_paste_preview(Vector2i(5, 5), clipboard)
	assert_eq(_bm.paste_ghost_cells.size(), 2, "应计算 2 个粘贴预览格子")
	assert_eq(_bm.paste_ghost_types.size(), 2, "应有 2 个类型映射")

func test_set_paste_preview_line():
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	var anchors: Array[Vector2i] = [Vector2i(5, 5), Vector2i(7, 5)]
	_bm.set_paste_preview_line(anchors, clipboard)
	assert_eq(_bm.paste_ghost_cells.size(), 4, "2 锚点 × 2 偏移量 = 4 个预览格子")
	assert_eq(_bm.paste_ghost_types.size(), 4, "应有 4 个类型映射")

func test_set_paste_preview_line_dedup():
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	var anchors: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 5)]
	_bm.set_paste_preview_line(anchors, clipboard)
	assert_eq(_bm.paste_ghost_cells.size(), 1, "重复锚点应去重，只有 1 个预览格子")

func test_clear_paste_preview():
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	_bm.set_paste_preview(Vector2i(0, 0), clipboard)
	assert_false(_bm.paste_ghost_cells.is_empty(), "设置后应有预览")
	_bm.clear_paste_preview()
	assert_true(_bm.paste_ghost_cells.is_empty(), "清除后 paste_ghost_cells 应为空")
	assert_true(_bm.paste_ghost_types.is_empty(), "清除后 paste_ghost_types 应为空")

func test_select_ghost_show_and_hide():
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	_bm.show_select_ghost(cells)
	assert_eq(_bm.select_ghost_cells.size(), 3, "应有 3 个选择幽灵格子")
	_bm.hide_select_ghost()
	assert_true(_bm.select_ghost_cells.is_empty(), "隐藏后 select_ghost_cells 应为空")

func test_deselect_ghost_show_and_hide():
	var cells: Array[Vector2i] = [Vector2i(3, 3)]
	_bm.show_deselect_ghost(cells)
	assert_eq(_bm.deselect_ghost_cells.size(), 1, "应有 1 个取消选择幽灵格子")
	_bm.hide_deselect_ghost()
	assert_true(_bm.deselect_ghost_cells.is_empty(), "隐藏后 deselect_ghost_cells 应为空")

func test_get_building_node():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var node = _bm.get_building_node(Vector2i(0, 0))
	assert_not_null(node, "存在的位置应返回节点")
	assert_true(node is ContainerNode, "应为 ContainerNode 类型")
	assert_null(_bm.get_building_node(Vector2i(99, 99)), "不存在的位置应返回 null")

func test_get_building_node_name():
	var name_str = _bm.get_building_node_name(Vector2i(3, 7))
	assert_eq(name_str, "Building_3_7", "节点名应为 Building_x_y 格式")
	var name_str2 = _bm.get_building_node_name(Vector2i(-1, -5))
	assert_eq(name_str2, "Building_-1_-5", "负坐标也应正确格式化")

func test_set_paste_preview_empty_clipboard():
	_bm.set_paste_preview(Vector2i(0, 0), {})
	assert_true(_bm.paste_ghost_cells.is_empty(), "空剪贴板不应有预览")

func test_set_paste_preview_line_empty_clipboard():
	var anchors: Array[Vector2i] = [Vector2i(0, 0)]
	_bm.set_paste_preview_line(anchors, {})
	assert_true(_bm.paste_ghost_cells.is_empty(), "空剪贴板不应有行预览")
