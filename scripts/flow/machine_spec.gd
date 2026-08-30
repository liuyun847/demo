class_name MachineSpec
extends RefCounted

## 机器规格表：建筑类型 -> 端口布局（本地坐标，未旋转）。
## 方向约定：机器"面朝"方向 d，d ∈ {0东, 1南, 2西, 3北}（顺时针）。
## 本地坐标以"面朝东"为基准：前=(1,0) 后=(-1,0) 左=(0,-1) 右=(0,1)。
## 旋转 r 次顺时针：偏移 (x,y) -> (-y,x)。
## 例外：数字源无方向——没有固定端口，输出由模拟器按四邻扫描决定
## （优先级 SOURCE_OUTPUT_ORDER），方向字段对其无意义（存档/剪贴板仍保留）。
## 垃圾桶：本体格接受传送带推入销毁；FOUR_WAY_PORTS 仅用于贴脸投递对齐判定
## （方向无意义，消费面槽物品）；端口格不可停靠、不从旁格吸取；分流器/一体建筑四向对称端口。

# ---------- 建筑类型 id（唯一来源，供全项目引用） ----------
const T_BELT: String = "belt"
const T_NUM_SOURCE: String = "num_source"
const T_APPLIER: String = "applier"
const T_SPLITTER: String = "splitter"
const T_TRASH: String = "trash"
## 传送带+分流器一体建筑（分流器放在传送带上时自动转换；不进入库存栏）
const T_BELT_SPLITTER: String = "belt_splitter"

# ---------- 机器行为 kind ----------
const KIND_NUM_SOURCE: String = "num_source"
const KIND_APPLIER: String = "applier"
const KIND_SPLITTER: String = "splitter"
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
	T_TRASH: Color("#8d6e63"),
	T_BELT_SPLITTER: Color("#ba68c8"),
}

# ---------- 应用器输入口角色（SPECS 数组顺序，跨文件共享防漂移） ----------
# 数据口画半圆标记、操作口画方标记（MachineNode 绘制同索引）
const APPLIER_IN_DATA: int = 0
const APPLIER_IN_OP: int = 1

## 四向端口（分流器专用）：顺序固定 [E,S,W,N]（顺时针），与 splitter_phase 方向索引一致
const FOUR_WAY_PORTS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]

## type_id -> {"kind": String, "ins": Array[Vector2i], "outs": Array[Vector2i]}
const SPECS: Dictionary = {
	# 数字源：无方向——没有固定输出口，输出动态扫描四邻（见 KIND_NUM_SOURCE 触发逻辑），
	# 视觉上四边中点画输出候选点；outs 留空表示无固定端口
	T_NUM_SOURCE: {"kind": KIND_NUM_SOURCE, "ins": [], "outs": []},
	# 应用器：ins[0]=数据口（半圆标记，只收数字），ins[1]=操作口（方标记，收操作物品或数字 n=+n）
	T_APPLIER: {"kind": KIND_APPLIER, "ins": [Vector2i(0, -1), Vector2i(0, 1)], "outs": [Vector2i(1, 0)]},
	# 四向分流器：4 个方向口完全对称（东西南北均可入可出），端口顺序固定 [E,S,W,N]；
	# 模拟层按 splitter_phase / splitter_in_phase 轮询选择实际输入/输出方向（不区分输入输出）
	T_SPLITTER: {"kind": KIND_SPLITTER, "ins": FOUR_WAY_PORTS, "outs": FOUR_WAY_PORTS},
	# 垃圾桶：本体格接受带子推入销毁 + 四向贴脸投递（面槽）；端口格不可停靠，无输出
	T_TRASH: {"kind": KIND_TRASH, "ins": FOUR_WAY_PORTS, "outs": []},
	# 传送带+分流器一体：4 向端口同普通分流器；模拟时优先读取自身格物品（带子流入）
	T_BELT_SPLITTER: {"kind": KIND_BELT_SPLITTER, "ins": FOUR_WAY_PORTS, "outs": FOUR_WAY_PORTS},
}

# ---------- 方向工具 ----------

## 数字源无向输出优先级（固定北→东→南→西，与传送带移动阶段组顺序一致，
## 保证确定性：被占时换下一方向，全部不可投递则背压等待不产）
const SOURCE_OUTPUT_ORDER: Array[int] = [
	DIR_N, DIR_E, DIR_S, DIR_W,
]

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

## 是否为四向端口类型（端口方向对称，不随朝向旋转，保持 [E,S,W,N] 固定顺序）
## 分流器四向均分轮询；垃圾桶四向投递输入（仅消费面槽物品，端口格不可停靠）
static func is_four_way_port_type(type_id: String) -> bool:
	return type_id == T_SPLITTER or type_id == T_BELT_SPLITTER or type_id == T_TRASH

## 输入端口（世界坐标，已旋转；四向分流器例外——方向对称不旋转）
static func get_ins(type_id: String, dir: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var spec: Dictionary = get_spec(type_id)
	for off: Vector2i in spec.get("ins", []):
		if is_four_way_port_type(type_id):
			result.append(off)  # 四向端口对称：旋转无意义且会打乱 splitter_phase 索引顺序
		else:
			result.append(rotate_offset(off, dir))
	return result

## 输出端口（世界坐标，已旋转；四向分流器例外——方向对称不旋转）
static func get_outs(type_id: String, dir: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var spec: Dictionary = get_spec(type_id)
	for off: Vector2i in spec.get("outs", []):
		if is_four_way_port_type(type_id):
			result.append(off)  # 四向端口对称：旋转无意义且会打乱 splitter_phase 索引顺序
		else:
			result.append(rotate_offset(off, dir))
	return result

## 玩家可放置的全部建筑类型（UI 顺序）
static func get_placement_types() -> Array[String]:
	return [
		T_BELT, T_NUM_SOURCE, T_APPLIER,
		T_SPLITTER, T_TRASH,
	]

## 端口偏移统一视图（世界偏移，已旋转，供预览/绘制用）：
## 传送带后入前出（输入=来向，输出=流向）；机器用 SPECS 端口布局。
## 数字源无方向：无固定端口（预览不画方向箭头，输出见模拟器四邻扫描）。
## 返回 {"ins": Array[Vector2i], "outs": Array[Vector2i]}
static func get_port_offsets(type_id: String, dir: int) -> Dictionary:
	if type_id == T_BELT:
		return {
			"ins": [dir_to_offset((dir + 2) % 4)],
			"outs": [dir_to_offset(dir)],
		}
	if type_id == T_NUM_SOURCE:
		return {
			"ins": [],
			"outs": [],
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
		T_TRASH:
			return "垃圾桶"
		_:
			return "未知建筑"