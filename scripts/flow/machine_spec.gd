class_name MachineSpec
extends RefCounted

## 机器规格表：建筑类型 -> 端口布局（本地坐标，未旋转）。
## 方向约定：机器"面朝"方向 d，d ∈ {0东, 1南, 2西, 3北}（顺时针）。
## 本地坐标以"面朝东"为基准：前=(1,0) 后=(-1,0) 左=(0,-1) 右=(0,1)。
## 旋转 r 次顺时针：偏移 (x,y) -> (-y,x)。

# ---------- 建筑类型 id（唯一来源，供全项目引用） ----------
const T_BELT: String = "belt"
const T_NUM_SOURCE: String = "num_source"
const T_APPLIER: String = "applier"
const T_SPLITTER: String = "splitter"
const T_FILTER: String = "filter"
const T_TRASH: String = "trash"
## 传送带+分流器一体建筑（分流器放在传送带上时自动转换；不进入库存栏）
const T_BELT_SPLITTER: String = "belt_splitter"

# ---------- 机器行为 kind ----------
const KIND_NUM_SOURCE: String = "num_source"
const KIND_APPLIER: String = "applier"
const KIND_SPLITTER: String = "splitter"
const KIND_FILTER: String = "filter"
const KIND_TRASH: String = "trash"
const KIND_BELT_SPLITTER: String = "belt_splitter"

# 方向常量
const DIR_E: int = 0
const DIR_S: int = 1
const DIR_W: int = 2
const DIR_N: int = 3

## 建筑主色（供节点绘制/库存图标）
const TYPE_COLORS: Dictionary = {
	T_BELT: Color("#8d99ae"),
	T_NUM_SOURCE: Color("#4fc3f7"),
	T_APPLIER: Color("#81c784"),
	T_SPLITTER: Color("#ba68c8"),
	T_FILTER: Color("#f06292"),
	T_TRASH: Color("#8d6e63"),
	T_BELT_SPLITTER: Color("#ba68c8"),
}

## type_id -> {"kind": String, "ins": Array[Vector2i], "outs": Array[Vector2i]}
const SPECS: Dictionary = {
	T_NUM_SOURCE: {"kind": KIND_NUM_SOURCE, "ins": [], "outs": [Vector2i(1, 0)]},
	T_APPLIER: {"kind": KIND_APPLIER, "ins": [Vector2i(0, -1), Vector2i(0, 1)], "outs": [Vector2i(1, 0)]},
	T_SPLITTER: {"kind": KIND_SPLITTER, "ins": [Vector2i(-1, 0)], "outs": [Vector2i(1, 0), Vector2i(0, -1)]},
	# 筛选器：front=通过口，left=拒绝口
	T_FILTER: {"kind": KIND_FILTER, "ins": [Vector2i(-1, 0)], "outs": [Vector2i(1, 0), Vector2i(0, -1)]},
	T_TRASH: {"kind": KIND_TRASH, "ins": [Vector2i(-1, 0)], "outs": []},
	# 传送带+分流器一体：输入端仅用于视觉箭头/端口停靠；模拟时读取自身格物品
	T_BELT_SPLITTER: {"kind": KIND_BELT_SPLITTER, "ins": [Vector2i(-1, 0)], "outs": [Vector2i(1, 0), Vector2i(0, -1)]},
}

# ---------- 方向工具 ----------

## 方向 -> 移动偏移（传送带推进方向 / 机器朝向）
static func dir_to_offset(dir: int) -> Vector2i:
	match dir:
		DIR_E:
			return Vector2i(1, 0)
		DIR_S:
			return Vector2i(0, 1)
		DIR_W:
			return Vector2i(-1, 0)
		_:
			return Vector2i(0, -1)

## 顺时针旋转偏移 dir 次（dir 编号即顺时针转数：东→南→西→北）
## 顺时针 90°：公式 (x,y) -> (-y,x)
static func rotate_offset(off: Vector2i, dir: int) -> Vector2i:
	var result := off
	for i in range(dir % 4):
		result = Vector2i(-result.y, result.x)
	return result

# ---------- 查询 ----------

static func get_spec(type_id: String) -> Dictionary:
	return SPECS.get(type_id, {})

static func get_kind(type_id: String) -> String:
	var spec: Dictionary = get_spec(type_id)
	return spec.get("kind", "")

static func is_belt(type_id: String) -> bool:
	return type_id == T_BELT

## 传送带+分流器一体建筑（分流器放在传送带上时生成）
static func is_belt_splitter(type_id: String) -> bool:
	return type_id == T_BELT_SPLITTER

static func is_machine(type_id: String) -> bool:
	return not get_kind(type_id).is_empty()

static func is_known(type_id: String) -> bool:
	return is_belt(type_id) or is_machine(type_id)

## 输入端口（世界坐标，已旋转）
static func get_ins(type_id: String, dir: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var spec: Dictionary = get_spec(type_id)
	for off: Vector2i in spec.get("ins", []):
		result.append(rotate_offset(off, dir))
	return result

## 输出端口（世界坐标，已旋转）
static func get_outs(type_id: String, dir: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var spec: Dictionary = get_spec(type_id)
	for off: Vector2i in spec.get("outs", []):
		result.append(rotate_offset(off, dir))
	return result

## 玩家可放置的全部建筑类型（UI 顺序）
static func get_placement_types() -> Array[String]:
	return [
		T_BELT, T_NUM_SOURCE, T_APPLIER,
		T_SPLITTER, T_FILTER, T_TRASH,
	]

## 端口偏移统一视图（世界偏移，已旋转，供预览/绘制用）：
## 传送带后入前出（输入=来向，输出=流向）；机器用 SPECS 端口布局。
## 返回 {"ins": Array[Vector2i], "outs": Array[Vector2i]}
static func get_port_offsets(type_id: String, dir: int) -> Dictionary:
	if type_id == T_BELT:
		return {
			"ins": [dir_to_offset((dir + 2) % 4)],
			"outs": [dir_to_offset(dir)],
		}
	return {
		"ins": get_ins(type_id, dir),
		"outs": get_outs(type_id, dir),
	}

## 建筑主色（未知类型回退默认色）
static func get_color(type_id: String) -> Color:
	return TYPE_COLORS.get(type_id, GameConfig.BUILDING_DEFAULT_COLOR)

## 建筑显示名（节点/提示 UI 用）
static func get_display_name(type_id: String) -> String:
	match type_id:
		T_BELT:
			return "传送带"
		T_NUM_SOURCE:
			return "数字源"
		T_APPLIER:
			return "应用器"
		T_SPLITTER:
			return "分流器"
		T_BELT_SPLITTER:
			return "分流器(传送带)"
		T_FILTER:
			return "筛选器"
		T_TRASH:
			return "垃圾桶"
		_:
			return "未知建筑"