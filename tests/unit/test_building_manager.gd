extends GutTest

const _BM = preload("res://scripts/building/building_manager.gd")
const _GU = preload("res://scripts/grid/grid_utils.gd")

var _bm: BuildingManager = null


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.container_type_id):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.container_type_id, {"has_capacity": true, "is_buffer": true}],
		[GameConfig.pipe_type_id,      {"is_pipe": true}],
		[GameConfig.emitter_type_id,   {"is_emitter": true}],
		[GameConfig.collector_type_id, {"is_collector": true}],
		[GameConfig.brick_type_id,     {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		types.append(td)
	BuildingTypeManager.register_all(types)


func before_each() -> void:
	if _bm == null:
		preload("res://scripts/building/container_node.gd")
		preload("res://scripts/building/pipe_node.gd")
		preload("res://scripts/resources/building_data.gd")
	_bm = autoqfree(_BM.new())
	var pr: PipeRenderSystem = preload("res://scripts/building/pipe_render_system.gd").new()
	pr.name = "PipeRenderSystem"
	_bm.add_child(pr)
	add_child_autoqfree(_bm)

func test_has_building_empty() -> void:
	assert_false(_bm.has_building(Vector2i(0, 0)), "刚创建时不应有建筑")

func test_place_building() -> void:
	var result: bool = _bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	assert_true(result, "放置应成功")
	assert_true(_bm.has_building(Vector2i(0, 0)), "放置后该位置应有建筑")

func test_place_building_on_occupied() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	var result: bool = _bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	assert_false(result, "已占用位置不应能重复放置")

func test_place_building_returns_false_when_occupied() -> void:
	_bm.place_building(Vector2i(3, 3), GameConfig.container_type_id)
	assert_false(_bm.place_building(Vector2i(3, 3), GameConfig.container_type_id))

func test_place_building_container_type() -> void:
	var result: bool = _bm.place_building(Vector2i(1, 2), GameConfig.container_type_id)
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(1, 2)))

func test_place_building_pipe_type() -> void:
	var result: bool = _bm.place_building(Vector2i(4, 1), GameConfig.pipe_type_id)
	assert_true(result)

func test_place_building_default_type() -> void:
	var result: bool = _bm.place_building(Vector2i(7, 7), "default")
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(7, 7)))

func test_remove_building() -> void:
	_bm.place_building(Vector2i(2, 2), GameConfig.container_type_id)
	var removed: bool = _bm.remove_building(Vector2i(2, 2))
	assert_true(removed, "删除应成功")
	assert_false(_bm.has_building(Vector2i(2, 2)), "删除后该位置不应有建筑")

func test_remove_nonexistent_building() -> void:
	var removed: bool = _bm.remove_building(Vector2i(99, 99))
	assert_false(removed, "删除不存在的建筑应返回 false")

func test_get_all_buildings_data() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	var data: Dictionary = _bm.get_all_buildings_data()
	assert_eq(data.size(), 2, "应有 2 个建筑记录")
	assert_true(data.has(Vector2i(0, 0)), "应包含 (0, 0)")
	assert_true(data.has(Vector2i(1, 0)), "应包含 (1, 0)")

func test_get_all_buildings_data_isolation() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var data: Dictionary = _bm.get_all_buildings_data()
	data.erase(Vector2i(0, 0))
	assert_true(_bm.has_building(Vector2i(0, 0)), "副本的修改不应影响原数据")

func test_clear_all_buildings() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 1), GameConfig.pipe_type_id)
	_bm.clear_all_buildings()
	assert_eq(_bm.get_all_buildings_data().size(), 0, "清除后应无建筑")

func test_get_line_cells_horizontal() -> void:
	var cells: Array[Vector2i] = _GU.get_line_cells(Vector2i(0, 5), Vector2i(4, 5))
	assert_eq(cells.size(), 5, "水平线上应有 5 个格子")
	assert_eq(cells[0], Vector2i(0, 5))
	assert_eq(cells[4], Vector2i(4, 5))

func test_get_line_cells_vertical() -> void:
	var cells: Array[Vector2i] = _GU.get_line_cells(Vector2i(3, 0), Vector2i(3, 3))
	assert_eq(cells.size(), 4, "垂直线上应有 4 个格子")
	assert_eq(cells[0], Vector2i(3, 0))
	assert_eq(cells[3], Vector2i(3, 3))

func test_get_line_cells_reverse() -> void:
	var cells: Array[Vector2i] = _GU.get_line_cells(Vector2i(4, 5), Vector2i(0, 5))
	assert_eq(cells.size(), 5, "反向水平线也应有 5 个格子")

func test_get_line_cells_single_point() -> void:
	var cells: Array[Vector2i] = _GU.get_line_cells(Vector2i(2, 2), Vector2i(2, 2))
	assert_eq(cells.size(), 1, "单点应返回 1 个格子")
	assert_eq(cells[0], Vector2i(2, 2))

func test_get_l_cells_horizontal_then_vertical() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(3, 2), true)
	assert_eq(cells.size(), 6, "L形先横后纵: (0,0)→(3,2) 应有6格")
	assert_eq(cells[0], Vector2i(0, 0), "起点应为 (0,0)")
	assert_eq(cells[1], Vector2i(1, 0))
	assert_eq(cells[2], Vector2i(2, 0))
	assert_eq(cells[3], Vector2i(3, 0), "拐角应为 (3,0)")
	assert_eq(cells[4], Vector2i(3, 1))
	assert_eq(cells[5], Vector2i(3, 2), "终点应为 (3,2)")

func test_get_l_cells_vertical_then_horizontal() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(3, 2), false)
	assert_eq(cells.size(), 6, "L形先纵后横: (0,0)→(3,2) 应有6格")
	assert_eq(cells[0], Vector2i(0, 0), "起点应为 (0,0)")
	assert_eq(cells[1], Vector2i(0, 1))
	assert_eq(cells[2], Vector2i(0, 2), "拐角应为 (0,2)")
	assert_eq(cells[3], Vector2i(1, 2))
	assert_eq(cells[4], Vector2i(2, 2))
	assert_eq(cells[5], Vector2i(3, 2), "终点应为 (3,2)")

func test_get_l_cells_reverse() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(3, 2), Vector2i(0, 0), true)
	assert_eq(cells.size(), 6, "反向L形先横后纵: (3,2)→(0,0) 应有6格")
	assert_has(cells, Vector2i(0, 0))
	assert_has(cells, Vector2i(0, 1))
	assert_has(cells, Vector2i(0, 2))
	assert_has(cells, Vector2i(1, 2))
	assert_has(cells, Vector2i(2, 2))
	assert_has(cells, Vector2i(3, 2))

func test_get_l_cells_straight_line() -> void:
	var cells_h: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(5, 0), true)
	assert_eq(cells_h.size(), 6, "水平线L形退化为直线: 应有6格")
	var cells_v: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(0, 5), false)
	assert_eq(cells_v.size(), 6, "垂直线L形退化为直线: 应有6格")

func test_get_l_cells_single_point() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(2, 2), Vector2i(2, 2), true)
	assert_eq(cells.size(), 1, "单点L形: 应有1格")
	assert_eq(cells[0], Vector2i(2, 2))

func test_get_rect_cells() -> void:
	var cells: Array[Vector2i] = _GU.get_rect_cells(Vector2i(1, 1), Vector2i(3, 3))
	assert_eq(cells.size(), 9, "3x3 矩形应有 9 个格子")

func test_get_rect_cells_single() -> void:
	var cells: Array[Vector2i] = _GU.get_rect_cells(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(cells.size(), 1, "单点矩形应返回 1 个格子")

func test_get_rect_cells_reverse() -> void:
	var cells: Array[Vector2i] = _GU.get_rect_cells(Vector2i(3, 3), Vector2i(1, 1))
	assert_eq(cells.size(), 9, "反向矩形也应有 9 个格子")

func test_place_buildings_in_line() -> void:
	var cells: Array[Vector2i] = _GU.get_line_cells(Vector2i(0, 0), Vector2i(4, 0))
	var placed: int = _bm.place_buildings_in_line(cells, GameConfig.pipe_type_id)
	assert_eq(placed, 5, "应成功放置 5 个建筑")
	for i in range(5):
		assert_true(_bm.has_building(Vector2i(i, 0)))

func test_remove_buildings_in_rect() -> void:
	for x: int in range(3):
		for y: int in range(3):
			_bm.place_building(Vector2i(x, y), GameConfig.container_type_id)
	var cells: Array[Vector2i] = _GU.get_rect_cells(Vector2i(0, 0), Vector2i(2, 2))
	var removed: int = _bm.remove_buildings_in_rect(cells)
	assert_eq(removed, 9, "应成功删除 9 个建筑")

func test_get_buildings_in_cells() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.pipe_type_id)
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var result: Dictionary = _bm.get_buildings_in_cells(cells)
	assert_eq(result.size(), 2, "应在 3 个格子中找到 2 个建筑")

func test_get_building_type() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	assert_eq(_bm.get_building_type(Vector2i(0, 0)), GameConfig.container_type_id, "应返回正确的建筑类型")
	assert_eq(_bm.get_building_type(Vector2i(99, 99)), "", "不存在的位置应返回空字符串")

func test_get_building_data() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var data: BuildingData = _bm.get_building_data(Vector2i(0, 0))
	assert_not_null(data, "存在的位置应返回 BuildingData")
	if data:
		assert_eq(data.building_type, GameConfig.container_type_id, "building_type 应正确")
	assert_null(_bm.get_building_data(Vector2i(99, 99)), "不存在的位置应返回 null")

func test_get_building_node() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var node: Node2D = _bm.get_building_node(Vector2i(0, 0))
	assert_not_null(node, "存在的位置应返回节点")
	assert_true(node is ContainerNode, "应为 ContainerNode 类型")
	assert_null(_bm.get_building_node(Vector2i(99, 99)), "不存在的位置应返回 null")

func test_get_building_node_name() -> void:
	var name_str: String = _GU.get_building_node_name(Vector2i(3, 7))
	assert_eq(name_str, "Building_3_7", "节点名应为 Building_x_y 格式")
	var name_str2: String = _GU.get_building_node_name(Vector2i(-1, -5))
	assert_eq(name_str2, "Building_-1_-5", "负坐标也应正确格式化")

func test_clear_all_buildings_silent_removes_all_buildings() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.clear_all_buildings_silent()
	assert_eq(_bm.get_all_buildings_data().size(), 0, "clear_all_buildings_silent 后 buildings 应为空")


func test_clear_all_buildings_silent_clears_fluid_lists() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.clear_all_buildings_silent()
	assert_true(_bm.network_pipes.is_empty(), "clear_all_buildings_silent 后 network_pipes 应为空")


func test_clear_all_buildings_silent_empty() -> void:
	_bm.clear_all_buildings_silent()
	assert_true(true, "无建筑时 clear_all_buildings_silent 不应崩溃")


func test_clear_all_buildings_silent_marks_reaction_coordinator_dirty() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	var coordinator: Node = _bm.get_node_or_null("ReactionCoordinator")
	if coordinator:
		coordinator._dirty = false
	_bm.clear_all_buildings_silent()
	if coordinator:
		assert_true(coordinator._dirty, "clear_all_buildings_silent 后 ReactionCoordinator 的 _dirty 应为 true")


func test_refresh_pipe_connections_on_place() -> void:
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	var pipe: PipeNode = _bm.get_building_node(Vector2i(1, 0)) as PipeNode
	assert_eq(pipe.connection_mask, 0, "孤立管道连接掩码应为 0")
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	var pipe_left: PipeNode = _bm.get_building_node(Vector2i(1, 0)) as PipeNode
	assert_true(pipe_left.connection_mask > 0, "相邻管道放置后连接掩码应更新")


func test_refresh_pipe_connections_on_remove() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	var pipe: PipeNode = _bm.get_building_node(Vector2i(1, 0)) as PipeNode
	assert_true(pipe.connection_mask > 0, "有邻居时连接掩码应 > 0")
	_bm.remove_building(Vector2i(0, 0))
	assert_eq(pipe.connection_mask, 0, "移除邻居后连接掩码应清零")
