extends GutTest

const _ContainerNode = preload("res://scripts/building/container_node.gd")
const _EmitterScript = preload("res://scripts/building/emitter_node.gd")


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


func _make_container_data() -> BuildingData:
	var data := BuildingData.new()
	data.building_type = GameConfig.container_type_id
	return data


func _make_emitter_data() -> BuildingData:
	var data := BuildingData.new()
	data.building_type = GameConfig.emitter_type_id
	return data


# ========== 容器路径 ==========

func test_sync_capacity_pull_from_node_when_no_restore() -> void:
	var data := _make_container_data()
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	node.max_capacity = 200
	node.capacity = 75
	BuildingDataSyncService.sync_from_node(data, node, {})
	assert_eq(data.capacity, 75, "未提供 restore_data 时应从节点拉取 capacity")
	assert_eq(data.max_capacity, 200, "未提供 restore_data 时应从节点拉取 max_capacity")


func test_sync_capacity_apply_restore_data() -> void:
	var data := _make_container_data()
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	BuildingDataSyncService.sync_from_node(data, node, {"capacity": 50, "max_capacity": 300})
	assert_eq(data.capacity, 50, "restore 应写入 BuildingData")
	assert_eq(data.max_capacity, 300)
	assert_eq(node.capacity, 50, "restore 应同步写入节点")
	assert_eq(node.max_capacity, 300)


func test_sync_capacity_partial_restore_data() -> void:
	var data := _make_container_data()
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	node.capacity = 10
	node.max_capacity = 100
	BuildingDataSyncService.sync_from_node(data, node, {"capacity": 25})
	assert_eq(data.capacity, 25, "应仅写入提供的字段")


# ========== 发射器路径 ==========

func test_sync_emitter_pull_from_node() -> void:
	var data := _make_emitter_data()
	var node: EmitterNode = autoqfree(_EmitterScript.new())
	node.element_type_id = "water"
	node.output_direction = Vector2i(1, 0)
	BuildingDataSyncService.sync_from_node(data, node, {})
	assert_eq(data.element_type_id, "water")
	assert_eq(data.output_direction, Vector2i(1, 0))


func test_sync_emitter_restore_array_format() -> void:
	var data := _make_emitter_data()
	var node: EmitterNode = autoqfree(_EmitterScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"output_direction": [1, 0]})
	assert_eq(data.output_direction, Vector2i(1, 0), "Array 格式应被解析")
	assert_eq(node.output_direction, Vector2i(1, 0))


func test_sync_emitter_restore_vector2i_format() -> void:
	var data := _make_emitter_data()
	var node: EmitterNode = autoqfree(_EmitterScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"output_direction": Vector2i(0, -1)})
	assert_eq(data.output_direction, Vector2i(0, -1))


func test_sync_emitter_restore_string_format() -> void:
	var data := _make_emitter_data()
	var node: EmitterNode = autoqfree(_EmitterScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"output_direction": "-1,0"})
	assert_eq(data.output_direction, Vector2i(-1, 0), "String 格式应被解析")


func test_sync_emitter_unknown_direction_format_falls_back() -> void:
	var data := _make_emitter_data()
	var node: EmitterNode = autoqfree(_EmitterScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"output_direction": 12345})
	assert_eq(data.output_direction, Vector2i(0, 1), "无法解析时应回退默认 (0,1)")


func test_sync_emitter_restore_element_type() -> void:
	var data := _make_emitter_data()
	var node: EmitterNode = autoqfree(_EmitterScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"element_type_id": "water"})
	assert_eq(data.element_type_id, "water")
	assert_eq(node.element_type_id, "water")


# ========== 异常路径 ==========

func test_sync_with_null_data_does_not_crash() -> void:
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	BuildingDataSyncService.sync_from_node(null, node, {})
	assert_true(true, "null data 应安全跳过")


func test_sync_with_null_node_does_not_crash() -> void:
	var data := _make_container_data()
	BuildingDataSyncService.sync_from_node(data, null, {})
	assert_true(true, "null node 应安全跳过")


func test_sync_capacity_with_non_container_node_skipped() -> void:
	# 直接调用 sync_capacity，传入非容器节点应直接返回
	var data := _make_container_data()
	var node: Node2D = autoqfree(Node2D.new())
	BuildingDataSyncService.sync_capacity(data, node, {"capacity": 999})
	assert_eq(data.capacity, 0, "非 ContainerNode 应跳过同步")


func test_sync_emitter_with_non_emitter_node_skipped() -> void:
	var data := _make_emitter_data()
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	BuildingDataSyncService.sync_emitter(data, node, {"output_direction": [1, 0]})
	assert_eq(data.output_direction, Vector2i(0, 1), "非 EmitterNode 应跳过同步")
