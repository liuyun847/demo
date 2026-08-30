extends GutTest

const _BM = preload("res://scripts/building/building_manager.gd")
const _GU = preload("res://scripts/grid/grid_utils.gd")

var _bm: BuildingManager = null


func before_all() -> void:
	BuildingTypeManager.register_defaults()


func before_each() -> void:
	_bm = autoqfree(_BM.new())
	add_child_autoqfree(_bm)

func test_has_building_empty() -> void:
	assert_false(_bm.has_building(Vector2i(10, 10)), "刚创建时 (10,10) 不应有建筑")

func test_place_belt() -> void:
	var result: bool = _bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_true(result, "放置应成功")
	assert_true(_bm.has_building(Vector2i(5, 5)), "放置后该位置应有建筑")
	var node := _bm.get_building_node(Vector2i(5, 5))
	assert_true(node is BeltNode, "传送带应创建 BeltNode")

func test_place_machine_with_direction() -> void:
	var result: bool = _bm.place_building(Vector2i(1, 2), MachineSpec.T_APPLIER, {"direction": MachineSpec.DIR_N})
	assert_true(result)
	var node := _bm.get_building_node(Vector2i(1, 2)) as MachineNode
	assert_true(node is MachineNode, "机器应创建 MachineNode")
	assert_eq(node.direction, MachineSpec.DIR_N, "restore 的方向应写入节点")
	assert_eq(_bm.get_building_data(Vector2i(1, 2)).direction, MachineSpec.DIR_N, "方向应同步到数据")

func test_place_machine_with_op_choice() -> void:
	# op_choice 字段保留（通用容器/旧存档兼容），用应用器验证 restore 写入
	var result: bool = _bm.place_building(Vector2i(1, 2), MachineSpec.T_APPLIER, {"op_choice": OpRegistry.OP_ADD1})
	assert_true(result)
	var node := _bm.get_building_node(Vector2i(1, 2)) as MachineNode
	assert_eq(node.op_choice, OpRegistry.OP_ADD1, "操作选择应写入节点")
	assert_eq(_bm.get_building_data(Vector2i(1, 2)).op_choice, OpRegistry.OP_ADD1, "操作选择应同步到数据")

func test_place_building_on_occupied() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	var result: bool = _bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_false(result, "已占用位置不应能重复放置")

# ---------- 分流器放传送带上（一体建筑 belt_splitter） ----------

func test_place_splitter_on_belt_converts_to_combo() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_N})
	var result: bool = _bm.place_building(Vector2i(5, 5), MachineSpec.T_SPLITTER, {"direction": MachineSpec.DIR_N})
	assert_true(result, "分流器应能放在传送带上")
	assert_eq(_bm.get_building_type(Vector2i(5, 5)), MachineSpec.T_BELT_SPLITTER, "应转换为一体建筑")
	var node := _bm.get_building_node(Vector2i(5, 5))
	assert_true(node is BeltSplitterNode, "应创建 BeltSplitterNode 复合节点")
	assert_eq(_bm.get_building_data(Vector2i(5, 5)).direction, MachineSpec.DIR_N, "方向应恢复")

func test_place_splitter_on_belt_uses_restore_direction() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_S})
	var result: bool = _bm.place_building(Vector2i(5, 5), MachineSpec.T_SPLITTER, {"direction": MachineSpec.DIR_N})
	assert_true(result)
	assert_eq(_bm.get_building_data(Vector2i(5, 5)).direction, MachineSpec.DIR_N, "方向应取 restore_data")

func test_place_splitter_on_belt_fallback_belt_direction() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_W})
	var result: bool = _bm.place_building(Vector2i(5, 5), MachineSpec.T_SPLITTER)
	assert_true(result)
	assert_eq(_bm.get_building_data(Vector2i(5, 5)).direction, MachineSpec.DIR_W, "无 restore 方向时沿用原带方向")

func test_place_machine_on_belt_refused() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_false(_bm.place_building(Vector2i(5, 5), MachineSpec.T_APPLIER), "应用器不能放在传送带上")
	assert_false(_bm.place_building(Vector2i(5, 5), MachineSpec.T_TRASH), "垃圾桶不能放在传送带上")
	assert_eq(_bm.get_building_type(Vector2i(5, 5)), MachineSpec.T_BELT, "格上应保持传送带")

func test_place_splitter_on_non_belt_occupied_refused() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_APPLIER)
	assert_false(_bm.place_building(Vector2i(5, 5), MachineSpec.T_SPLITTER), "分流器不能放在机器格上")

func test_remove_belt_splitter_removes_both() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_SPLITTER)
	var removed: bool = _bm.remove_building(Vector2i(5, 5))
	assert_true(removed, "一体建筑应可删除")
	assert_false(_bm.has_building(Vector2i(5, 5)), "一体建筑删除后该格应为空地（带子一并删除）")

func test_place_belt_splitter_direct_on_empty() -> void:
	# 粘贴/撤销/存档恢复路径：一体建筑可直接放在空格（自带传送带层）
	var result: bool = _bm.place_building(Vector2i(8, 8), MachineSpec.T_BELT_SPLITTER, {
		"direction": MachineSpec.DIR_S,
		"splitter_phase": 1,
	})
	assert_true(result)
	var data := _bm.get_building_data(Vector2i(8, 8))
	assert_eq(data.building_type, MachineSpec.T_BELT_SPLITTER)
	assert_eq(data.direction, MachineSpec.DIR_S)
	assert_eq(data.splitter_phase, 1)
	assert_true(_bm.get_building_node(Vector2i(8, 8)) is BeltSplitterNode)

func test_can_place_rules() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_true(_bm.can_place(Vector2i(5, 5), MachineSpec.T_SPLITTER), "传送带格可放分流器")
	assert_true(_bm.can_place(Vector2i(5, 5), MachineSpec.T_BELT_SPLITTER), "传送带格可放一体建筑")
	assert_false(_bm.can_place(Vector2i(5, 5), MachineSpec.T_APPLIER), "其他机器不可放传送带上")
	assert_false(_bm.can_place(Vector2i(5, 5), MachineSpec.T_BELT), "传送带不能放传送带")
	assert_true(_bm.can_place(Vector2i(9, 9), MachineSpec.T_APPLIER), "空格任意类型可放")

func test_place_building_default_type_placeholder() -> void:
	var result: bool = _bm.place_building(Vector2i(7, 7), "default")
	assert_true(result)
	assert_true(_bm.has_building(Vector2i(7, 7)))

func test_remove_building() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	var removed: bool = _bm.remove_building(Vector2i(5, 5))
	assert_true(removed, "删除应成功")
	assert_false(_bm.has_building(Vector2i(5, 5)), "删除后该位置不应有建筑")

func test_remove_nonexistent_building() -> void:
	var removed: bool = _bm.remove_building(Vector2i(99, 99))
	assert_false(removed, "删除不存在的建筑应返回 false")

func test_get_all_buildings_data() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(6, 5), MachineSpec.T_NUM_SOURCE)
	var data: Dictionary = _bm.get_all_buildings_data()
	assert_eq(data.size(), 2, "2 个建筑 = 2 个记录（无核心）")
	assert_true(data.has(Vector2i(5, 5)))
	assert_true(data.has(Vector2i(6, 5)))

func test_get_all_buildings_data_isolation() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	var data: Dictionary = _bm.get_all_buildings_data()
	data.erase(Vector2i(5, 5))
	assert_true(_bm.has_building(Vector2i(5, 5)), "副本的修改不应影响原数据")

func test_clear_all_buildings() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(6, 6), MachineSpec.T_BELT)
	_bm.clear_all_buildings()
	assert_true(_bm.get_all_buildings_data().is_empty(), "清除后应为空")

## 网格工具测试（与流体时代同源，保留）

func test_get_axis_aligned_cells_horizontal() -> void:
	var cells: Array[Vector2i] = _GU.get_axis_aligned_cells(Vector2i(0, 5), Vector2i(4, 5))
	assert_eq(cells.size(), 5, "水平线上应有 5 个格子")
	assert_eq(cells[0], Vector2i(0, 5))
	assert_eq(cells[4], Vector2i(4, 5))

func test_get_axis_aligned_cells_vertical() -> void:
	var cells: Array[Vector2i] = _GU.get_axis_aligned_cells(Vector2i(3, 0), Vector2i(3, 3))
	assert_eq(cells.size(), 4, "垂直线上应有 4 个格子")
	assert_eq(cells[0], Vector2i(3, 0))
	assert_eq(cells[3], Vector2i(3, 3))

func test_get_axis_aligned_cells_reverse() -> void:
	var cells: Array[Vector2i] = _GU.get_axis_aligned_cells(Vector2i(4, 5), Vector2i(0, 5))
	assert_eq(cells.size(), 5, "反向水平线也应有 5 个格子")

func test_get_axis_aligned_cells_single_point() -> void:
	var cells: Array[Vector2i] = _GU.get_axis_aligned_cells(Vector2i(2, 2), Vector2i(2, 2))
	assert_eq(cells.size(), 1, "单点应返回 1 个格子")
	assert_eq(cells[0], Vector2i(2, 2))

func test_get_l_cells_horizontal_then_vertical() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(3, 2), true)
	assert_eq(cells.size(), 6, "L形先横后纵: (0,0)→(3,2) 应有6格")
	assert_eq(cells[0], Vector2i(0, 0), "起点应为 (0,0)")
	assert_eq(cells[5], Vector2i(3, 2), "终点应为 (3,2)")

func test_get_l_cells_vertical_then_horizontal() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(3, 2), false)
	assert_eq(cells.size(), 6, "L形先纵后横: (0,0)→(3,2) 应有6格")
	assert_eq(cells[0], Vector2i(0, 0), "起点应为 (0,0)")
	assert_eq(cells[5], Vector2i(3, 2), "终点应为 (3,2)")

func test_get_l_cells_reverse() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(3, 2), Vector2i(0, 0), true)
	assert_eq(cells.size(), 6, "反向L形先横后纵: (3,2)→(0,0) 应有6格")
	assert_has(cells, Vector2i(0, 0))
	assert_has(cells, Vector2i(3, 2))

func test_get_l_cells_straight_line() -> void:
	var cells_h: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(5, 0), true)
	assert_eq(cells_h.size(), 6, "水平线L形退化为直线: 应有6格")
	var cells_v: Array[Vector2i] = _GU.get_l_cells(Vector2i(0, 0), Vector2i(0, 5), false)
	assert_eq(cells_v.size(), 6, "垂直线L形退化为直线: 应有6格")

func test_get_l_cells_single_point() -> void:
	var cells: Array[Vector2i] = _GU.get_l_cells(Vector2i(2, 2), Vector2i(2, 2), true)
	assert_eq(cells.size(), 1, "单点L形: 应有1格")

func test_get_rect_cells() -> void:
	var cells: Array[Vector2i] = _GU.get_rect_cells(Vector2i(1, 1), Vector2i(3, 3))
	assert_eq(cells.size(), 9, "3x3 矩形应有 9 个格子")

func test_place_buildings_in_line() -> void:
	var cells: Array[Vector2i] = _GU.get_axis_aligned_cells(Vector2i(2, 0), Vector2i(6, 0))
	var placed: int = _bm.place_buildings_in_line(cells, MachineSpec.T_BELT)
	assert_eq(placed, 5, "应成功放置 5 个建筑")

func test_remove_buildings_in_rect() -> void:
	for x: int in range(3):
		for y: int in range(3):
			_bm.place_building(Vector2i(x + 5, y + 5), MachineSpec.T_BELT)
	var cells: Array[Vector2i] = _GU.get_rect_cells(Vector2i(5, 5), Vector2i(7, 7))
	var removed: int = _bm.remove_buildings_in_rect(cells)
	assert_eq(removed, 9, "应成功删除 9 个建筑")

func test_get_buildings_in_cells() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(5, 6), MachineSpec.T_BELT)
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 6), Vector2i(5, 7)]
	var result: Dictionary = _bm.get_buildings_in_cells(cells)
	assert_eq(result.size(), 2, "应在 3 个格子中找到 2 个建筑")

func test_get_building_type() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_eq(_bm.get_building_type(Vector2i(5, 5)), MachineSpec.T_BELT, "应返回正确的建筑类型")
	assert_eq(_bm.get_building_type(Vector2i(99, 99)), "", "不存在的位置应返回空字符串")

func test_get_building_node() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_APPLIER)
	var node: Node2D = _bm.get_building_node(Vector2i(5, 5))
	assert_not_null(node, "存在的位置应返回节点")
	assert_true(node is MachineNode, "应为 MachineNode 类型")
	assert_null(_bm.get_building_node(Vector2i(99, 99)), "不存在的位置应返回 null")

func test_flow_systems_created() -> void:
	assert_not_null(_bm.get_node_or_null("ItemFlowCoordinator"), "应创建物品流协调器")
	assert_not_null(_bm.get_flow_coordinator(), "get_flow_coordinator 应可用")
	assert_not_null(_bm.get_node_or_null("ItemRenderer"), "应创建物品渲染器")

func test_clear_all_buildings_silent_clears_grid_and_renderer() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_NUM_SOURCE)
	_bm.place_building(Vector2i(6, 5), MachineSpec.T_BELT)
	var coord := _bm.get_flow_coordinator()
	coord._on_tick()
	assert_eq(coord.grid.count_items(), 1, "tick 后数字源应产 1（喂入相邻带格）")
	_bm.clear_all_buildings_silent()
	assert_true(_bm.get_all_buildings_data().is_empty(), "清除后建筑应为空")
	assert_true(coord.grid.is_empty(), "清除后物品格应为空")

func test_clear_all_buildings_silent_empty() -> void:
	_bm.clear_all_buildings_silent()
	assert_true(true, "无建筑时 clear_all_buildings_silent 不应崩溃")

## clear_all_buildings 时 building_removed 信号对每个建筑触发一次
func test_clear_all_buildings_emits_signal_per_building() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(6, 6), MachineSpec.T_BELT)
	watch_signals(EventBus)
	_bm.clear_all_buildings()
	assert_signal_emit_count(EventBus, "building_removed", 2, "应触发 2 次 building_removed 信号")


## 需求 3：删除传送带时其上物品应被清理，不残留空地上（含 despawn 事件）
func test_remove_building_clears_items_on_gone_belt() -> void:
	_bm.place_building(Vector2i(0, 0), MachineSpec.T_NUM_SOURCE)
	_bm.place_building(Vector2i(1, 0), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(2, 0), MachineSpec.T_BELT)
	var coord := _bm.get_flow_coordinator()
	coord._on_tick()
	# 源头产 1，移动阶段物品应停在带子末端 (2,0) 上（空地守卫：末端 (3,0) 不接收）
	assert_true(coord.grid.has_item(Vector2i(2, 0)), "tick 后物品应停在带子末端")
	# 删除末端带子 (2,0)：该格无任何建筑/端口支撑，物品应被清理
	var received: Array = []
	var cb := func(e: Array) -> void:
		received.append(e)
	EventBus.sim_tick_completed.connect(cb)
	_bm.remove_building(Vector2i(2, 0))
	EventBus.sim_tick_completed.disconnect(cb)
	assert_false(coord.grid.has_item(Vector2i(2, 0)), "删除传送带后其上物品应被清理")
	assert_false(coord.grid.has_item(Vector2i(0, 0)), "机器自身格不应有物品")
	if not received.is_empty():
		var events: Array = received[0]
		var has_despawn := false
		for e: Dictionary in events:
			if e.get("kind", "") == "despawn" and e.get("at", Vector2i.MIN) == Vector2i(2, 0):
				has_despawn = true
		assert_true(has_despawn, "删除建筑应发射该格的 despawn 事件（渲染层同步消失）")


## 需求 3：删除机器时其端口格（输入/输出）上残留物品应一并清理
func test_remove_machine_clears_items_on_ports() -> void:
	# 应用器 (0,0) E：ins=(0,-1)/(0,1)，out=(1,0)；手动在端口格放物品模拟残留
	_bm.place_building(Vector2i(0, 0), MachineSpec.T_APPLIER)
	var coord := _bm.get_flow_coordinator()
	coord.grid.set_item(Vector2i(1, 0), Item.num(9))
	_bm.remove_building(Vector2i(0, 0))
	assert_false(coord.grid.has_item(Vector2i(1, 0)), "删除机器后输出端口格残留物品应被清理")
	assert_false(coord.grid.has_item(Vector2i(0, -1)), "删除机器后输入端口格残留物品应被清理")


## W1 回归：端口重叠（两机器输出口同一格）时，删除其一不得误删仍被另一机器支撑的物品
func test_remove_machine_keeps_items_on_shared_port() -> void:
	# 分流器 (0,0) E 的 front 口与应用器 (2,0) W 的输出口重叠在 (1,0)
	_bm.place_building(Vector2i(0, 0), MachineSpec.T_SPLITTER)
	_bm.place_building(Vector2i(2, 0), MachineSpec.T_APPLIER, {"direction": MachineSpec.DIR_W})
	var coord := _bm.get_flow_coordinator()
	coord.grid.set_item(Vector2i(1, 0), Item.num(42))
	# 删除应用器：其端口 (1,0) 仍是分流器输出口（可停靠格），物品应保留
	_bm.remove_building(Vector2i(2, 0))
	assert_true(coord.grid.has_item(Vector2i(1, 0)), "共享端口上的物品应保留（仍被另一机器支撑）")
	# 再删分流器：(1,0) 失去支撑，物品应被清理
	_bm.remove_building(Vector2i(0, 0))
	assert_false(coord.grid.has_item(Vector2i(1, 0)), "失去全部支撑后端口残留物品应被清理")


## 0 格贴脸直传：删除生产者时应清理其面槽上等待的面物品（despawn 事件）
func test_remove_producer_clears_pending_face_item() -> void:
	# 源(0,-6) 贴脸喂分流器(1,-6)；应用器(2,-6) 堵住前口（不对齐）→ 面槽持有物品
	_bm.place_building(Vector2i(0, -6), MachineSpec.T_NUM_SOURCE)
	_bm.place_building(Vector2i(1, -6), MachineSpec.T_SPLITTER)
	_bm.place_building(Vector2i(2, -6), MachineSpec.T_APPLIER)
	var coord := _bm.get_flow_coordinator()
	coord._on_tick()
	coord._on_tick()
	assert_eq(coord.grid.count_edge_items(), 1, "面槽应持有 1 个等待物品")
	var received: Array = []
	var cb := func(e: Array) -> void:
		received.append(e)
	EventBus.sim_tick_completed.connect(cb)
	_bm.remove_building(Vector2i(0, -6))
	EventBus.sim_tick_completed.disconnect(cb)
	assert_eq(coord.grid.count_edge_items(), 0, "删除生产者后其面物品应被清理")
	if not received.is_empty():
		var has_face_despawn := false
		for e: Dictionary in received[0]:
			if e.get("kind", "") == "despawn" and e.has("face"):
				has_face_despawn = true
		assert_true(has_face_despawn, "面物品清理应发 despawn 事件（带 face 定位）")


## 0 格贴脸直传：删除消费者（互认对齐目标消失）后，滞留面物品同样应清理
func test_remove_consumer_clears_orphaned_face_item() -> void:
	# 源(0,-6) 贴脸喂分流器(1,-6)；分流器左口先被占（交替位=1）→ 面槽滞留
	_bm.place_building(Vector2i(0, -6), MachineSpec.T_NUM_SOURCE)
	_bm.place_building(Vector2i(1, -6), MachineSpec.T_SPLITTER, {"splitter_phase": 1})
	var coord := _bm.get_flow_coordinator()
	coord.grid.set_item(Vector2i(1, -7), Item.num(9))  # 左口被占
	coord._on_tick()
	coord._on_tick()
	assert_eq(coord.grid.count_edge_items(), 1, "面槽应滞留（分流器出口被堵）")
	_bm.remove_building(Vector2i(1, -6))
	assert_eq(coord.grid.count_edge_items(), 0, "删除消费者后对齐目标消失, 面物品应被清理")