class_name BuildingDataSyncService
extends RefCounted

# 将节点状态同步到 BuildingData，必要时根据 restore_data 反向写入节点。
# 此服务取代旧的 BuildingData.sync_*_from_node 静态方法，负责所有数据/节点同步逻辑。

static func sync_from_node(data: BuildingData, node: Node, restore_data: Dictionary = {}) -> void:
	if data == null:
		push_warning("BuildingDataSyncService.sync_from_node: data 为 null，跳过同步")
		return
	if node == null:
		push_warning("BuildingDataSyncService.sync_from_node: node 为 null，跳过同步")
		return
	if BuildingTypeManager.is_source(data.building_type):
		_sync_source(data, node, restore_data)
	elif BuildingTypeManager.is_collector(data.building_type):
		_sync_collector(data, node, restore_data)


## 同步源头节点数据。element_type_id 为节点当前类型，restore_data 非空时反写节点。
static func sync_source(data: BuildingData, node: Node, restore_data: Dictionary = {}) -> void:
	if data == null:
		push_warning("BuildingDataSyncService.sync_source: data 为 null，跳过同步")
		return
	if node == null:
		push_warning("BuildingDataSyncService.sync_source: node 为 null，跳过同步")
		return
	_sync_source(data, node, restore_data)


static func _sync_source(data: BuildingData, node: Node, restore_data: Dictionary) -> void:
	if not (node is SourceNode):
		return

	if not restore_data.is_empty():
		if restore_data.has("element_type_id"):
			var type_id: String = restore_data["element_type_id"]
			data.element_type_id = type_id
			node.element_type_id = type_id
			if node.has_method("set_element_type"):
				node.set_element_type(type_id)
	else:
		var source_node := node as SourceNode
		# 未确认类型（关闭态）不落盘元素类型，重载后保持关闭不产出
		data.element_type_id = source_node.element_type_id if source_node.has_type_selected() else ""


## 同步收集器节点数据。collector_filter 为筛选元素类型，restore_data 非空时反写节点。
static func sync_collector(data: BuildingData, node: Node, restore_data: Dictionary = {}) -> void:
	if data == null:
		push_warning("BuildingDataSyncService.sync_collector: data 为 null，跳过同步")
		return
	if node == null:
		push_warning("BuildingDataSyncService.sync_collector: node 为 null，跳过同步")
		return
	_sync_collector(data, node, restore_data)


static func _sync_collector(data: BuildingData, node: Node, restore_data: Dictionary) -> void:
	if not (node is CollectorNode):
		return

	if not restore_data.is_empty():
		if restore_data.has("collector_filter"):
			var filter_id: String = restore_data["collector_filter"]
			data.collector_filter = filter_id
			node.filter_element_type = filter_id
			if node.has_method("set_filter"):
				node.set_filter(filter_id)
	else:
		data.collector_filter = node.filter_element_type
