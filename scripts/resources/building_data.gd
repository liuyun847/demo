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
## 分流器输出轮询方向（0东 1南 2西 3北；增量记忆=上一轮输出方向+1，投递成功后 +1 循环，被占跳过不重置）
var splitter_phase: int = 0
## 分流器输入轮询方向（0东 1南 2西 3北；增量记忆=上一轮输入方向+1，读取成功后 +1 循环，多输入链交替读取）
var splitter_in_phase: int = 0
## 最近一次输出方向（-1 = 从未投递；0东 1南 2西 3北）。供 _find_input 跳过"刚投出的
## 方向"防循环搬运。独立字段而非 phase 反推：一体建筑自身格投递后 phase 可回绕 0 且
## in_phase 保持 0（自身格读取不推进输入相位），反推会误判"从未投递"导致跳过失效。
## 纯运行时记忆，不落盘/不进剪贴板（重启回退 -1 = 初始态，语义正确）。
var last_out_dir: int = -1
## 分流器按输出方向独立的过滤条件（下标=方向 0东1南2西3北；空字典 = 无条件放行）。
## 条件形如 {"kind":"num","cmp":"gt|lt|eq|ne","value":int} 或 {"kind":"op","value":op_id}；
## 物品只能从"无条件或条件匹配"的方向输出，全部不匹配 = 背压等待（物品不丢）。
var splitter_filters: Array = [{}, {}, {}, {}]


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
	cloned.splitter_phase = splitter_phase
	cloned.splitter_in_phase = splitter_in_phase
	cloned.last_out_dir = last_out_dir
	# 深拷贝过滤条件（外层数组 + 每条条件字典都独立）
	cloned.splitter_filters = _clone_filters(splitter_filters)
	return cloned


## 过滤条件深拷贝：逐条 duplicate（空字典/非字典条目保持语义）
static func _clone_filters(filters: Array) -> Array:
	var result: Array = []
	for cond: Variant in filters:
		result.append(cond.duplicate(true) if cond is Dictionary else {})
	return result
