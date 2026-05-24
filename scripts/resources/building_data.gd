class_name BuildingData
extends RefCounted

var grid_position: Vector2i
var building_type: String = "default"
var capacity: int = 0
var max_capacity: int = 100
var element_type_id: String = ""

static func has_capacity(type_id: String) -> bool:
	return type_id == GameConfig.container_type_id

static func is_pipe_or_buffer(type_id: String) -> bool:
	return type_id == GameConfig.container_type_id or \
		   type_id == GameConfig.pipe_type_id

static func is_container_building(node: Node) -> bool:
	return node is ContainerNode

static func is_emitter(type_id: String) -> bool:
	return type_id == GameConfig.emitter_type_id

static func is_collector(type_id: String) -> bool:
	return type_id == GameConfig.collector_type_id

static func sync_capacity_from_node(data: BuildingData, node: Node, restore_data: Dictionary = {}) -> void:
	if not is_container_building(node):
		return

	if not restore_data.is_empty():
		if restore_data.has("capacity") and "capacity" in node:
			data.capacity = restore_data["capacity"]
			node.capacity = restore_data["capacity"]
		if restore_data.has("max_capacity") and "max_capacity" in node:
			data.max_capacity = restore_data["max_capacity"]
			node.max_capacity = restore_data["max_capacity"]
	else:
		if "capacity" in node:
			data.capacity = node.capacity
		if "max_capacity" in node:
			data.max_capacity = node.max_capacity

static func sync_emitter_type_from_node(data: BuildingData, node: Node) -> void:
	if not (node is EmitterNode):
		return
	data.element_type_id = node.element_type_id

static func is_emitter_node(node: Node) -> bool:
	return node is EmitterNode

static func is_collector_node(node: Node) -> bool:
	return node is CollectorNode
