class_name BuildingData
extends RefCounted

# 纯数据容器：仅持有建筑实例的运行时数据。
# 类型判断 → BuildingTypeManager；节点同步 → BuildingDataSyncService。

var grid_position: Vector2i
var building_type: String = "default"
var capacity: int = 0
var max_capacity: int = 100
var element_type_id: String = ""
## 收集器筛选元素类型：空字符串 = 收全部（默认，兼容旧存档）
var collector_filter: String = ""


func clone() -> BuildingData:
	var cloned := BuildingData.new()
	cloned.grid_position = grid_position
	cloned.building_type = building_type
	cloned.capacity = capacity
	cloned.max_capacity = max_capacity
	cloned.element_type_id = element_type_id
	cloned.collector_filter = collector_filter
	return cloned
