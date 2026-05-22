class_name BuildingData
extends RefCounted

var grid_position: Vector2i
var building_type: String = "default"
var capacity: int = 0
var max_capacity: int = 100

static func has_capacity(type_id: String) -> bool:
	return type_id == GameConfig.container_type_id

static func is_fluid_building(type_id: String) -> bool:
	return type_id == GameConfig.container_type_id or \
		   type_id == GameConfig.pipe_type_id

static func is_container_building(node: Node) -> bool:
	return node is ContainerNode
