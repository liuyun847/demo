class_name BuildingData
extends RefCounted

var grid_position: Vector2i
var building_type: String = "default"
var capacity: int = 0
var max_capacity: int = 100

static func has_capacity(building_type: String) -> bool:
	return building_type == GameConfig.container_type_id

static func is_fluid_building(building_type: String) -> bool:
	return building_type == GameConfig.container_type_id or \
		   building_type == GameConfig.pipe_type_id or \
		   building_type == GameConfig.water_source_type_id

static func is_fluid_storage_building(node: Node) -> bool:
	return node is ContainerNode
