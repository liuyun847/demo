extends GutTest

const _EmitterScript = preload("res://scripts/building/emitter_node.gd")


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.pipe_type_id):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
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


func _make_emitter_data() -> BuildingData:
	var data := BuildingData.new()
	data.building_type = GameConfig.emitter_type_id
	return data


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

func test_sync_emitter_with_non_emitter_node_skipped() -> void:
	var data := _make_emitter_data()
	var node: Node2D = autoqfree(Node2D.new())
	BuildingDataSyncService.sync_emitter(data, node, {"output_direction": [1, 0]})
	assert_eq(data.output_direction, Vector2i(0, 1), "非 EmitterNode 应跳过同步")
