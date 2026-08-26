extends GutTest

## BuildingDataSyncService：物品流字段（direction/op_choice/filter/splitter_phase）
## 节点 <-> 数据双向同步 + entry 助手测试。

var _data: BuildingData = null

func before_each() -> void:
	_data = BuildingData.new()
	_data.building_type = MachineSpec.T_APPLIER

func _make_belt_node() -> BeltNode:
	var node := BeltNode.new()
	node.building_type = MachineSpec.T_BELT
	return autoqfree(node)

func _make_machine_node() -> MachineNode:
	var node := MachineNode.new()
	node.building_type = MachineSpec.T_APPLIER
	return autoqfree(node)

func test_node_to_data_belt_direction() -> void:
	var node := _make_belt_node()
	node.set_direction(MachineSpec.DIR_W)
	BuildingDataSyncService.sync_from_node(_data, node)
	assert_eq(_data.direction, MachineSpec.DIR_W, "节点朝向应同步到数据")

func test_node_to_data_machine_fields() -> void:
	var node := _make_machine_node()
	node.direction = MachineSpec.DIR_S
	node.op_choice = OpRegistry.OP_SUB1
	node.filter_kind = "op"
	node.filter_value = OpRegistry.OP_NEG
	node.splitter_phase = 1
	BuildingDataSyncService.sync_from_node(_data, node)
	assert_eq(_data.direction, MachineSpec.DIR_S)
	assert_eq(_data.op_choice, OpRegistry.OP_SUB1)
	assert_eq(_data.filter_kind, "op")
	assert_eq(_data.filter_cmp, "gt", "未改动的比较字段保持默认")
	assert_eq(_data.filter_value, OpRegistry.OP_NEG)
	assert_eq(_data.splitter_phase, 1)

func test_restore_data_applies_to_node_and_data() -> void:
	var node := _make_machine_node()
	var restore_data := {
		"direction": MachineSpec.DIR_N,
		"op_choice": OpRegistry.OP_MUL2,
		"filter_kind": "num",
		"filter_cmp": "lt",
		"filter_value": 7,
		"splitter_phase": 1,
	}
	BuildingDataSyncService.sync_from_node(_data, node, restore_data)
	assert_eq(_data.direction, MachineSpec.DIR_N)
	assert_eq(_data.op_choice, OpRegistry.OP_MUL2)
	assert_eq(_data.filter_cmp, "lt")
	assert_eq(_data.filter_value, 7)
	assert_eq(_data.splitter_phase, 1)
	assert_eq(node.direction, MachineSpec.DIR_N, "restore 应写回节点")
	assert_eq(node.op_choice, OpRegistry.OP_MUL2)
	assert_eq(node.filter_kind, "num")

func test_restore_partial_fields() -> void:
	var node := _make_machine_node()
	BuildingDataSyncService.sync_from_node(_data, node, {"direction": MachineSpec.DIR_S})
	assert_eq(_data.direction, MachineSpec.DIR_S)
	assert_eq(_data.op_choice, -1, "未提供的字段保持默认")
	assert_eq(node.op_choice, -1)

func test_sync_non_flow_node_noop() -> void:
	# 未知/非物品流节点不应同步也不崩溃
	var plain: Node = autofree(Node.new())
	BuildingDataSyncService.sync_from_node(_data, plain)
	assert_eq(_data.direction, 0, "非物品流节点不改变数据")

func test_entry_to_restore_data() -> void:
	var entry := {
		"type": MachineSpec.T_FILTER,
		"direction": 2,
		"op_choice": 3,
		"filter_kind": "op",
		"filter_value": 4,
	}
	var restore := BuildingDataSyncService.entry_to_restore_data(entry)
	assert_eq(restore.direction, 2)
	assert_eq(restore.op_choice, 3)
	assert_eq(restore.filter_kind, "op")
	assert_eq(restore.filter_value, 4)
	assert_false(restore.has("splitter_phase"), "缺失字段不出现")

func test_data_to_entry_defaults_omitted() -> void:
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_NUM_SOURCE
	data.direction = 0
	data.op_choice = -1
	data.filter_kind = "num"
	data.filter_cmp = "gt"
	data.filter_value = 0
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_eq(entry.type, MachineSpec.T_NUM_SOURCE)
	assert_eq(entry.direction, 0, "朝向总是记录")
	assert_false(entry.has("op_choice"), "未选择操作不记录")
	assert_false(entry.has("filter_kind"), "默认筛选配置不记录")

func test_data_to_entry_custom_fields() -> void:
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_SPLITTER
	data.direction = 3
	data.splitter_phase = 1
	data.op_choice = OpRegistry.OP_IS_ZERO
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_eq(entry.direction, 3)
	assert_eq(entry.splitter_phase, 1)
	assert_eq(entry.op_choice, OpRegistry.OP_IS_ZERO)
	assert_eq(entry.op_def, "iszero", "操作选择应附带稳定定义串")

func test_composite_op_entry_carries_definition() -> void:
	# 复合操作必须携带定义串，否则重载后 id 失效会静默停产
	var comp := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_APPLIER
	data.op_choice = comp
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_eq(entry.op_choice, comp)
	assert_true(entry.has("op_def"), "复合操作应记录定义串")
	var restore := BuildingDataSyncService.entry_to_restore_data(entry)
	assert_true(restore.has("op_def"), "restore_data 应透传定义串")
	# 模拟跨会话：清空注册表后用定义串恢复
	OpRegistry.reset()
	var restored := OpRegistry.ensure_from_definition(str(restore.op_def))
	assert_true(restored >= 0, "定义串恢复应成功")
	assert_eq(OpRegistry.apply(restored, 3), 8, "恢复后语义一致：先 +1 再 ×2")

func test_filter_op_entry_carries_definition() -> void:
	var comp := OpRegistry.compose(OpRegistry.OP_SUB1, OpRegistry.OP_NEG)
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_FILTER
	data.filter_kind = "op"
	data.filter_cmp = "eq"
	data.filter_value = comp
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_true(entry.has("filter_op_def"), "op 筛选应记录定义串")
	var restore := BuildingDataSyncService.entry_to_restore_data(entry)
	OpRegistry.reset()
	var restored := OpRegistry.ensure_from_definition(str(restore.filter_op_def))
	assert_eq(OpRegistry.apply(restored, 4), -3, "恢复后语义一致：先 -1 得 3，再取反得 -3")