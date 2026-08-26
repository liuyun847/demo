extends GutTest

const _BuildingData = preload("res://scripts/resources/building_data.gd")
const _BM = preload("res://scripts/building/building_manager.gd")


func before_all() -> void:
	BuildingTypeManager.register_defaults()


func _setup_bm() -> BuildingManager:
	var bm: BuildingManager = autoqfree(_BM.new() as BuildingManager)
	add_child_autoqfree(bm)
	return bm

func test_building_data_creation() -> void:
	var data: BuildingData = BuildingData.new()
	data.grid_position = Vector2i(3, 5)
	data.building_type = MachineSpec.T_BELT
	data.direction = MachineSpec.DIR_S

	assert_eq(data.grid_position, Vector2i(3, 5), "grid_position 应正确赋值")
	assert_eq(data.building_type, MachineSpec.T_BELT, "building_type 应正确赋值")
	assert_eq(data.direction, MachineSpec.DIR_S, "direction 应正确赋值")

func test_building_data_defaults() -> void:
	var data: BuildingData = BuildingData.new()
	assert_eq(data.building_type, "default", "默认 building_type 应为 default")
	assert_eq(data.direction, 0, "默认方向应为东")
	assert_eq(data.op_choice, -1, "默认操作选择应为 -1")
	assert_eq(data.filter_kind, "num", "默认筛选类型应为数字")
	assert_eq(data.filter_cmp, "gt", "默认筛选比较应为 >")
	assert_eq(data.filter_value, 0, "默认筛选值应为 0")
	assert_eq(data.splitter_phase, 0, "默认分流交替位应为 0")

func test_building_data_clone_copies_flow_fields() -> void:
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_FILTER
	data.direction = 2
	data.op_choice = OpRegistry.OP_ADD1
	data.filter_kind = "op"
	data.filter_cmp = "eq"
	data.filter_value = OpRegistry.OP_NEG
	data.splitter_phase = 1
	var copy := data.clone()
	copy.direction = 0
	assert_eq(data.direction, 2, "克隆修改不应影响原数据")
	assert_eq(copy.filter_kind, "op")
	assert_eq(copy.filter_value, OpRegistry.OP_NEG)
	assert_eq(copy.splitter_phase, 1)

func test_building_type_manager_helpers() -> void:
	assert_true(BuildingTypeManager.is_belt(MachineSpec.T_BELT))
	assert_false(BuildingTypeManager.is_belt(MachineSpec.T_APPLIER))
	assert_true(BuildingTypeManager.is_machine(MachineSpec.T_APPLIER))
	assert_true(BuildingTypeManager.is_known(MachineSpec.T_TRASH))
	assert_false(BuildingTypeManager.is_known("type_02"), "旧类型应视为未知")

## 端口偏移统一视图：传送带后入前出（预览箭头用），机器与 SPECS 一致
func test_port_offsets_belt_and_machine() -> void:
	var belt_e := MachineSpec.get_port_offsets(MachineSpec.T_BELT, MachineSpec.DIR_E)
	assert_eq(belt_e.ins, [Vector2i(-1, 0)], "东向带输入在后方")
	assert_eq(belt_e.outs, [Vector2i(1, 0)], "东向带输出在前方")
	var belt_n := MachineSpec.get_port_offsets(MachineSpec.T_BELT, MachineSpec.DIR_N)
	assert_eq(belt_n.ins, [Vector2i(0, 1)], "北向带输入在下方")
	assert_eq(belt_n.outs, [Vector2i(0, -1)], "北向带输出在上方")
	var applier := MachineSpec.get_port_offsets(MachineSpec.T_APPLIER, MachineSpec.DIR_E)
	assert_eq(applier.ins, MachineSpec.get_ins(MachineSpec.T_APPLIER, MachineSpec.DIR_E), "机器输入与 SPECS 一致")
	assert_eq(applier.outs, MachineSpec.get_outs(MachineSpec.T_APPLIER, MachineSpec.DIR_E), "机器输出与 SPECS 一致")
	var trash := MachineSpec.get_port_offsets(MachineSpec.T_TRASH, MachineSpec.DIR_W)
	assert_true((trash.outs as Array).is_empty(), "垃圾桶无输出")

func test_undo_command_place_type() -> void:
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {
		Vector2i(10, 10): {"type": MachineSpec.T_BELT}
	}
	assert_eq(cmd.type, UndoCommand.Type.PLACE, "类型应为 PLACE")
	assert_eq(cmd.buildings.size(), 1, "应包含一个建筑记录")

func test_undo_command_reverse_adds_building() -> void:
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.REMOVE
	cmd.buildings = {
		Vector2i(10, 20): {"type": MachineSpec.T_BELT}
	}
	var bm: BuildingManager = _setup_bm()
	cmd.reverse(bm)
	assert_true(bm.has_building(Vector2i(10, 20)), "reverse 应在指定位置放置建筑")

func test_undo_command_reverse_place_removes_building() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_true(bm.has_building(Vector2i(5, 5)), "放置后应有建筑")
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(5, 5): {"type": MachineSpec.T_BELT}}
	cmd.reverse(bm)
	assert_false(bm.has_building(Vector2i(5, 5)), "reverse PLACE 应删除建筑")

func test_undo_command_reverse_cut_restores_direction() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(3, 3), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_N})
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(3, 3): {"type": MachineSpec.T_BELT, "direction": MachineSpec.DIR_N}}
	bm.remove_building(Vector2i(3, 3))
	assert_false(bm.has_building(Vector2i(3, 3)), "删除后不应有建筑")
	cmd.reverse(bm)
	assert_true(bm.has_building(Vector2i(3, 3)), "reverse CUT 应恢复建筑")
	assert_eq(bm.get_building_data(Vector2i(3, 3)).direction, MachineSpec.DIR_N, "朝向应恢复")

func test_undo_command_reverse_cut_restores_op_choice() -> void:
	# op_choice 字段保留（通用容器/旧存档兼容），用应用器验证撤销恢复
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(4, 4), MachineSpec.T_APPLIER, {"op_choice": OpRegistry.OP_MUL2})
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(4, 4): {"type": MachineSpec.T_APPLIER, "op_choice": OpRegistry.OP_MUL2}}
	bm.remove_building(Vector2i(4, 4))
	cmd.reverse(bm)
	var node := bm.get_building_node(Vector2i(4, 4)) as MachineNode
	assert_not_null(node, "恢复后节点应存在")
	assert_eq(node.op_choice, OpRegistry.OP_MUL2, "操作选择应恢复")

func test_undo_command_forward_remove() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_true(bm.has_building(Vector2i(5, 5)), "放置后应有建筑")
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.REMOVE
	cmd.buildings = {Vector2i(5, 5): {"type": MachineSpec.T_BELT}}
	cmd.forward(bm)
	assert_false(bm.has_building(Vector2i(5, 5)), "forward REMOVE 应删除建筑")

func test_undo_command_forward_cut() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	assert_true(bm.has_building(Vector2i(5, 5)), "放置后应有建筑")
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(5, 5): {"type": MachineSpec.T_BELT}}
	cmd.forward(bm)
	assert_false(bm.has_building(Vector2i(5, 5)), "forward CUT 应删除建筑")