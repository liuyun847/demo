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

# ---------- 新函数式工厂字段 ----------
## 建筑朝向：0东 1南 2西 3北（MachineSpec.DIR_*；传送带推进方向、机器端口朝向）
var direction: int = 0
## 操作选择 id（通用容器，保留兼容旧条目；-1 = 未选择；当前无建筑产生新值）
var op_choice: int = -1
## 筛选器谓词：kind ∈ {"num","op"}，cmp ∈ {"eq","ne","gt","lt"}，value 为比较值
## （kind=op 时忽略 cmp，等价按操作 id 相等匹配）
var filter_kind: String = "num"
var filter_cmp: String = "gt"
var filter_value: int = 0
## 分流器交替位：0=走 front 口，1=走 left 口（送达后翻转）
var splitter_phase: int = 0


func clone() -> BuildingData:
	var cloned := BuildingData.new()
	cloned.grid_position = grid_position
	cloned.building_type = building_type
	cloned.capacity = capacity
	cloned.max_capacity = max_capacity
	cloned.element_type_id = element_type_id
	cloned.collector_filter = collector_filter
	cloned.direction = direction
	cloned.op_choice = op_choice
	cloned.filter_kind = filter_kind
	cloned.filter_cmp = filter_cmp
	cloned.filter_value = filter_value
	cloned.splitter_phase = splitter_phase
	return cloned
