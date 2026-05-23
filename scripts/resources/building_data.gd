class_name BuildingData
extends RefCounted

var grid_position: Vector2i
var building_type: String = "default"
var capacity: int = 0
var max_capacity: int = 100

static func has_capacity(type_id: String) -> bool:
	return type_id == GameConfig.container_type_id

static func is_pipe_or_buffer(type_id: String) -> bool:
	return type_id == GameConfig.container_type_id or \
		   type_id == GameConfig.pipe_type_id

static func is_container_building(node: Node) -> bool:
	return node is ContainerNode

static func is_emitter(type_id: String) -> bool:
	return type_id in [
		GameConfig.emitter_water_type_id,
		GameConfig.emitter_fire_type_id,
		GameConfig.emitter_earth_type_id,
	]

static func is_collector(type_id: String) -> bool:
	return type_id == GameConfig.collector_type_id

static func is_emitter_node(node: Node) -> bool:
	return node is EmitterNode

static func is_collector_node(node: Node) -> bool:
	return node is CollectorNode
