extends GutTest

const _SourceScript = preload("res://scripts/building/source_node.gd")
const _CollectorScript = preload("res://scripts/building/collector_node.gd")


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.PIPE_TYPE_ID):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.PIPE_TYPE_ID,      {"category": BuildingTypeData.Category.PIPE}],
		[GameConfig.SOURCE_TYPE_ID,    {"category": BuildingTypeData.Category.SOURCE}],
		[GameConfig.COLLECTOR_TYPE_ID, {"category": BuildingTypeData.Category.COLLECTOR}],
		[GameConfig.BRICK_TYPE_ID,     {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		types.append(td)
	BuildingTypeManager.register_all(types)


func _make_source_data() -> BuildingData:
	var data := BuildingData.new()
	data.building_type = GameConfig.SOURCE_TYPE_ID
	return data


func _make_collector_data() -> BuildingData:
	var data := BuildingData.new()
	data.building_type = GameConfig.COLLECTOR_TYPE_ID
	return data


# ========== 源头路径 ==========

func test_sync_source_pull_from_node() -> void:
	var data := _make_source_data()
	var node: SourceNode = autoqfree(_SourceScript.new())
	node.set_element_type("water")
	BuildingDataSyncService.sync_from_node(data, node, {})
	assert_eq(data.element_type_id, "water")
	assert_true(node.has_type_selected(), "set_element_type 后节点应标记为已确认")


func test_sync_source_restore_element_type() -> void:
	var data := _make_source_data()
	var node: SourceNode = autoqfree(_SourceScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"element_type_id": "water"})
	assert_eq(data.element_type_id, "water")
	assert_eq(node.element_type_id, "water")
	assert_true(node.has_type_selected(), "通过 restore_data 设置后节点应标记为已确认")


# ========== 收集器路径 ==========

func test_sync_collector_pull_from_node() -> void:
	var data := _make_collector_data()
	var node: CollectorNode = autoqfree(_CollectorScript.new())
	node.set_filter("water")
	BuildingDataSyncService.sync_from_node(data, node, {})
	assert_eq(data.collector_filter, "water")


func test_sync_collector_restore_filter() -> void:
	var data := _make_collector_data()
	var node: CollectorNode = autoqfree(_CollectorScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {"collector_filter": "fire"})
	assert_eq(data.collector_filter, "fire")
	assert_eq(node.filter_element_type, "fire")


func test_sync_collector_empty_filter_default() -> void:
	var data := _make_collector_data()
	var node: CollectorNode = autoqfree(_CollectorScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {})
	assert_eq(data.collector_filter, "", "空筛选为默认值（收全部）")
	assert_eq(node.filter_element_type, "")


# ========== 异常路径 ==========

func test_sync_source_with_non_source_node_skipped() -> void:
	var data := _make_source_data()
	var node: Node2D = autoqfree(Node2D.new())
	BuildingDataSyncService.sync_source(data, node, {"element_type_id": "water"})
	assert_eq(data.element_type_id, "", "非 SourceNode 应跳过同步，data 保持默认空字符串")


func test_sync_collector_with_non_collector_node_skipped() -> void:
	var data := _make_collector_data()
	var node: Node2D = autoqfree(Node2D.new())
	BuildingDataSyncService.sync_collector(data, node, {"collector_filter": "water"})
	assert_eq(data.collector_filter, "", "非 CollectorNode 应跳过同步，data 保持默认空字符串")


# ========== 回归保护：output_direction 字段应被忽略 ==========

func test_sync_source_ignores_legacy_output_direction() -> void:
	# 旧存档可能携带 output_direction 字段，应被静默忽略（不报错、不影响同步）
	var data := _make_source_data()
	var node: SourceNode = autoqfree(_SourceScript.new())
	BuildingDataSyncService.sync_from_node(data, node, {
		"output_direction": [1, 0],
		"element_type_id": "water",
	})
	assert_eq(data.element_type_id, "water", "应正常同步 element_type_id")
	assert_false("output_direction" in data, "BuildingData 不应再持有 output_direction 属性")
