extends GutTest

## BuildingDataSyncService：物品流字段（direction/op_choice/splitter_phase/splitter_in_phase/
## splitter_filters）节点 <-> 数据双向同步 + entry 助手测试。

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
	node.set_splitter_filter(MachineSpec.DIR_E, {"kind": "num", "cmp": "gt", "value": 5})
	node.splitter_phase = 1
	node.splitter_in_phase = 2
	BuildingDataSyncService.sync_from_node(_data, node)
	assert_eq(_data.direction, MachineSpec.DIR_S)
	assert_eq(_data.op_choice, OpRegistry.OP_SUB1)
	assert_eq(str(_data.splitter_filters[MachineSpec.DIR_E].get("kind", "")), "num", "按方向过滤条件应同步到数据")
	assert_eq(int(_data.splitter_filters[MachineSpec.DIR_E].get("value", -1)), 5)
	assert_true((_data.splitter_filters[MachineSpec.DIR_S] as Dictionary).is_empty(), "未设置方向保持无条件")
	assert_eq(_data.splitter_phase, 1)
	assert_eq(_data.splitter_in_phase, 2)

func test_restore_data_applies_to_node_and_data() -> void:
	var node := _make_machine_node()
	var restore_data := {
		"direction": MachineSpec.DIR_N,
		"op_choice": OpRegistry.OP_MUL2,
		"splitter_filters": [{"kind": "num", "cmp": "lt", "value": 7}, {}, {}, {}],
		"splitter_phase": 1,
		"splitter_in_phase": 3,
	}
	BuildingDataSyncService.sync_from_node(_data, node, restore_data)
	assert_eq(_data.direction, MachineSpec.DIR_N)
	assert_eq(_data.op_choice, OpRegistry.OP_MUL2)
	assert_eq(int(_data.splitter_filters[0].get("value", -1)), 7)
	assert_eq(str(node.splitter_filters[0].get("kind", "")), "num", "restore 应写回节点过滤条件")
	assert_true((node.splitter_filters[1] as Dictionary).is_empty(), "其余方向无条件")
	assert_eq(_data.splitter_phase, 1)
	assert_eq(_data.splitter_in_phase, 3, "输入轮询相位应恢复")
	assert_eq(node.direction, MachineSpec.DIR_N, "restore 应写回节点")
	assert_eq(node.op_choice, OpRegistry.OP_MUL2)

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
		"type": MachineSpec.T_SPLITTER,
		"direction": 2,
		"op_choice": 3,
		"splitter_filters": [{}, {"kind": "op", "value": 4}, {}, {}],
	}
	var restore := BuildingDataSyncService.entry_to_restore_data(entry)
	assert_eq(restore.direction, 2)
	assert_eq(restore.op_choice, 3)
	assert_eq(int(restore.splitter_filters[1].get("value", -1)), 4, "splitter_filters 应透传")
	assert_false(restore.has("splitter_phase"), "缺失字段不出现")

func test_data_to_entry_defaults_omitted() -> void:
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_NUM_SOURCE
	data.direction = 0
	data.op_choice = -1
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_eq(entry.type, MachineSpec.T_NUM_SOURCE)
	assert_eq(entry.direction, 0, "朝向总是记录")
	assert_false(entry.has("op_choice"), "未选择操作不记录")
	assert_false(entry.has("splitter_filters"), "全无条件时不记录过滤配置")

func test_data_to_entry_custom_fields() -> void:
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_SPLITTER
	data.direction = 3
	data.splitter_phase = 1
	data.splitter_in_phase = 2
	data.op_choice = OpRegistry.OP_IS_ZERO
	data.splitter_filters[MachineSpec.DIR_W] = {"kind": "num", "cmp": "gt", "value": 0}
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_eq(entry.direction, 3)
	assert_eq(entry.splitter_phase, 1)
	assert_eq(entry.splitter_in_phase, 2)
	assert_eq(entry.op_choice, OpRegistry.OP_IS_ZERO)
	assert_eq(entry.op_def, "iszero", "操作选择应附带稳定定义串")
	assert_eq(int(entry.splitter_filters[MachineSpec.DIR_W].get("value", -1)), 0, "有条件方向应落盘")
	assert_true((entry.splitter_filters[0] as Dictionary).is_empty(), "无条件方向落盘为空字典")

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

func test_splitter_filter_op_entry_carries_definition() -> void:
	# 复合操作条件必须携带定义串，否则重载后 id 失效会静默变成无条件方向
	var comp := OpRegistry.compose(OpRegistry.OP_SUB1, OpRegistry.OP_NEG)
	var data := BuildingData.new()
	data.building_type = MachineSpec.T_SPLITTER
	data.splitter_filters[MachineSpec.DIR_E] = {"kind": "op", "value": comp}
	var entry := BuildingDataSyncService.data_to_entry(data)
	assert_true((entry.splitter_filters[0] as Dictionary).has("op_def"), "op 条件应记录定义串")
	var restore := BuildingDataSyncService.entry_to_restore_data(entry)
	OpRegistry.reset()
	var filters := BuildingDataSyncService._restore_filters(restore.splitter_filters)
	assert_eq(int(filters[0].get("value", -1)), OpRegistry.ensure_from_definition("[\"compose\", \"sub1\", \"neg\"]"), "定义串应重建复合操作 id")
	assert_eq(OpRegistry.apply(int(filters[0].get("value", -1)), 4), -3, "恢复后语义一致：先 -1 得 3，再取反得 -3")

func test_restore_filters_malformed_entries() -> void:
	# 脏数据防御：非数组/尺寸不足/未知 kind/非法 op id 均归为无条件
	assert_eq(BuildingDataSyncService._restore_filters("bad").size(), 4)
	var r1 := BuildingDataSyncService._restore_filters([{"kind": "num", "cmp": "eq", "value": 1}])
	assert_eq(int(r1[0].get("value", -1)), 1)
	assert_true((r1[3] as Dictionary).is_empty(), "尺寸不足补空")
	var r2 := BuildingDataSyncService._restore_filters([{"kind": "weird"}, {"kind": "op", "value": 9999}, "junk", 42])
	for cond: Variant in r2:
		assert_true((cond as Dictionary).is_empty(), "未知 kind/非法 id/非字典均归无条件")