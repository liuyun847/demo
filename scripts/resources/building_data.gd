class_name BuildingData
extends RefCounted

# 纯数据容器：仅持有建筑实例的运行时数据。
# 类型判断 → BuildingTypeManager；节点同步 → BuildingDataSyncService。

var grid_position: Vector2i
var building_type: String = "default"
var capacity: int = 0
var max_capacity: int = 100
var element_type_id: String = ""
var output_direction: Vector2i = Vector2i(0, 1)


func clone() -> BuildingData:
	var cloned := BuildingData.new()
	cloned.grid_position = grid_position
	cloned.building_type = building_type
	cloned.capacity = capacity
	cloned.max_capacity = max_capacity
	cloned.element_type_id = element_type_id
	cloned.output_direction = output_direction
	return cloned
