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
	if BuildingTypeManager.is_emitter(data.building_type):
		_sync_emitter(data, node, restore_data)


static func sync_emitter(data: BuildingData, node: Node, restore_data: Dictionary = {}) -> void:
	_sync_emitter(data, node, restore_data)


static func _sync_emitter(data: BuildingData, node: Node, restore_data: Dictionary) -> void:
	if not (node is EmitterNode):
		return

	if not restore_data.is_empty():
		if restore_data.has("element_type_id"):
			var type_id: String = restore_data["element_type_id"]
			data.element_type_id = type_id
			node.element_type_id = type_id
			if node.has_method("set_element_type"):
				node.set_element_type(type_id)
		if restore_data.has("output_direction"):
			var resolved_dir: Vector2i = _parse_direction(restore_data["output_direction"])
			data.output_direction = resolved_dir
			node.output_direction = resolved_dir
			if node.has_method("set_output_direction"):
				node.set_output_direction(resolved_dir)
	else:
		data.element_type_id = node.element_type_id
		data.output_direction = node.output_direction


static func _parse_direction(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is String:
		var parts := (value as String).split(",")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	push_warning("BuildingDataSyncService._parse_direction: 无法解析方向值 %s，使用默认 (0,1)" % str(value))
	return Vector2i(0, 1)
