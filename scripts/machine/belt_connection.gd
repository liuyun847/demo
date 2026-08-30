class_name BeltConnection
extends RefCounted

## 传送带连接分析（纯静态，无节点依赖，可直接单元测试）。
## 为每格传送带（含传送带+分流器一体建筑）计算邻居连接信息，供节点绘制
## 连续连接带/转弯/T 型接驳/端口供料视觉：
##   feed   ：主喂入边（-1 = 无上游，视觉从格心起画；多条上游时取第一条）
##   feeds  ：全部喂入边（多上游合流格每条都画带，避免一条入流无带体衔接）
##   exits  ：物品从哪些边离开本格（带子=自身方向；一体建筑=四向）
##   taps   ：本格被哪些机器输入口抽取（机器相对本格的偏移，画 T 形支路）
##   fed_by ：哪些机器的输出口正对本格（机器相对本格的偏移，画接驳短线）
## 消费方契约：taps/fed_by 存"机器相对本格的轴向单位偏移"，绘制端直接当方向向量乘
## 系数使用；禁止改回格子坐标（曾因此画出节点外的 45° 白条/超长支路）。
## 判定规则（与 ItemSimulator 语义一致）：
##   - 上游带：邻格带子方向迎向本格（N + dir == 本格 → 喂入）
##   - 机器输出口 == 本格 → 喂入（如数字源出口正对带格）
##   - 本格 ∈ 机器输入口 → 该机器抽取（taps；一体建筑的视觉输入口除外）
##   - 机器本体格贴脸直传不经过带子，不在此表范围内（机器侧另行绘制）

# 无上游哨兵
const NO_FEED: int = -1

## 计算全部带格连接信息，返回 Dictionary[Vector2i, Dictionary]
static func compute(buildings: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in buildings.keys():
		var data: BuildingData = buildings[cell] as BuildingData
		if data == null:
			continue
		if MachineSpec.is_belt(data.building_type):
			result[cell] = _compute_belt_cell(buildings, cell, data, [])
		elif MachineSpec.is_belt_splitter(data.building_type):
			# 一体建筑：与带子同样的喂入/抽取分析，出口取四向（get_outs 已返回）
			var exits: Array[int] = []
			for off: Vector2i in MachineSpec.get_outs(data.building_type, data.direction):
				exits.append(offset_to_dir(off))
			result[cell] = _compute_belt_cell(buildings, cell, data, exits)
	return result

## 计算单个带格（data 是带子或一体建筑的数据）
static func _compute_belt_cell(buildings: Dictionary, cell: Vector2i, data: BuildingData, extra_exits: Array[int]) -> Dictionary:
	var info := {
		"feed": NO_FEED,
		"feeds": [],
		"exits": [],
		"taps": [],
		"fed_by": [],
	}
	# 出口：自身方向（+ 一体建筑的额外口）
	var exits: Array[int] = [data.direction]
	for d: int in extra_exits:
		if not exits.has(d):
			exits.append(d)
	info["exits"] = exits
	# 喂入边 + 机器抽取 + 机器供给
	var feeds: Array[int] = []
	for off: Vector2i in DIR_OFFSETS_ALL:
		var n: Vector2i = cell + off
		var n_data: BuildingData = buildings.get(n) as BuildingData
		if n_data == null:
			continue
		if MachineSpec.is_belt(n_data.building_type) or MachineSpec.is_belt_splitter(n_data.building_type):
			# 上游带/一体建筑（带子语义）→ 喂入；一体建筑的视觉输入口不参与抽取（其输入=自身格）
			if n_data.direction == offset_to_dir(-off):
				var edge_dir := offset_to_dir(off)
				if not feeds.has(edge_dir):
					feeds.append(edge_dir)
			continue
		if not MachineSpec.is_machine(n_data.building_type):
			continue
		# 机器：输出口正对本格 → 喂入本格；输入口正对本格 → 本格被抽取
		# taps/fed_by 记录机器相对本格的偏移（绘制端直接当方向向量用）
		# 数字源（无方向）：四周相邻带格全部视为被喂入（fed_by），无需对齐输出口
		if MachineSpec.get_kind(n_data.building_type) == MachineSpec.KIND_NUM_SOURCE:
			(info["fed_by"] as Array).append(off)
			continue
		# 四向分流器：输入口覆盖四周（可能顺带抽取 → 保留 taps），输出不定向
		# （轮询选择 → 不画 fed_by 接驳短线，由机器本体十字骨架表达输出）
		var is_splitter: bool = (
			MachineSpec.get_kind(n_data.building_type) == MachineSpec.KIND_SPLITTER
			or MachineSpec.get_kind(n_data.building_type) == MachineSpec.KIND_BELT_SPLITTER
		)
		# 垃圾桶：输入=本体格（带子推入，由带格出口箭头表达）与面槽（贴脸投递），
		# 不从带格顺带抽取 → 不画 taps；无输出 → 不画 fed_by
		var is_trash: bool = MachineSpec.get_kind(n_data.building_type) == MachineSpec.KIND_TRASH
		var ins: Array[Vector2i] = MachineSpec.get_ins(n_data.building_type, n_data.direction)
		var outs: Array[Vector2i] = MachineSpec.get_outs(n_data.building_type, n_data.direction)
		if not is_trash and ins.has(-off):
			(info["taps"] as Array).append(off)
		if not is_splitter and not is_trash and outs.has(-off):
			(info["fed_by"] as Array).append(off)
	info["feeds"] = feeds
	info["feed"] = feeds[0] if not feeds.is_empty() else NO_FEED
	return info

## 偏移向量 → 方向编号（0东 1南 2西 3北）
static func offset_to_dir(off: Vector2i) -> int:
	match off:
		Vector2i(1, 0):
			return MachineSpec.DIR_E
		Vector2i(0, 1):
			return MachineSpec.DIR_S
		Vector2i(-1, 0):
			return MachineSpec.DIR_W
		_:
			return MachineSpec.DIR_N

# ---------- 绘制助手（BeltNode / BeltSplitterNode 共用；节点坐标系=格心原点） ----------

const BAND_COLOR: Color = Color("#b9c7d9")
const BAND_EDGE_COLOR: Color = Color(0.16, 0.17, 0.22, 0.85)
const CHEVRON_COLOR: Color = Color(1, 1, 1, 0.9)
const TAP_COLOR: Color = Color(0.55, 0.95, 0.65, 0.9)
const TAP_EDGE_LEN: float = 10.0

## 绘制一格带子的连接带：每条 feed 边（无上游则由格心起）→ 每条 exit 边，
## 弯折处画圆角；被机器顺带抽取时画 T 形支路（taps 为机器相对本格的偏移）；
## 机器输出口正对本格时画输入接驳短线（fed_by 为机器相对本格的偏移）。
static func draw_band(node: CanvasItem, info: Dictionary) -> void:
	var feeds: Array = info.get("feeds", [])
	var exits: Array = info.get("exits", [])
	var taps: Array = info.get("taps", [])
	var fed_by: Array = info.get("fed_by", [])
	var half := GameConfig.CELL_SIZE / 2.0
	# 无上游时单条从格心起画（feed=-1）；多上游时每条喂入边各画一段
	var feed_dirs: Array = feeds if not feeds.is_empty() else [NO_FEED]
	for d: int in exits:
		for f: int in feed_dirs:
			# 四向分流器出口含上游方向时跳过同向段（防往返线/零长度段）
			if f != NO_FEED and f == d:
				continue
			var start := Vector2.ZERO if f == NO_FEED else Vector2(MachineSpec.dir_to_offset(f)) * half
			var mid := Vector2.ZERO
			var end := Vector2(MachineSpec.dir_to_offset(d)) * half
			_draw_band_segment(node, start, mid, end)
	# 机器输出口直投本格：画从机器侧边中点向内接驳的短线（输入汇入带体）
	for machine_off: Vector2i in fed_by:
		var dv := Vector2(machine_off)
		node.draw_line(dv * (half - TAP_EDGE_LEN), dv * (half * 0.42), BAND_COLOR, 5.0, true)
	# T 形支路：本带被机器输入口顺带抽取（与流向垂直时形成 T 接）
	for tap_off: Vector2i in taps:
		var dirv := Vector2(tap_off)
		# 与某条出口同向时不重复画（带体已指向机器）
		var redundant := false
		for d: int in exits:
			if MachineSpec.dir_to_offset(d) == tap_off:
				redundant = true
				break
		if redundant:
			continue
		var start := dirv * (half * 0.55)
		var end := dirv * (half - TAP_EDGE_LEN)
		node.draw_line(start, end, TAP_COLOR, 5.0, true)
		_draw_tip(node, end, Vector2(dirv), TAP_COLOR, 5.0)

## 单条带段：起点(边中点或格心) → 格心 → 终点(边中点)，圆角 + 中心暗线 + 雪弗龙
static func _draw_band_segment(node: CanvasItem, start: Vector2, mid: Vector2, end: Vector2) -> void:
	var pts := PackedVector2Array([start, mid, end])
	node.draw_polyline(pts, BAND_COLOR, 14.0, true)
	node.draw_circle(mid, 7.0, BAND_COLOR)
	node.draw_polyline(pts, BAND_EDGE_COLOR, 3.0, true)
	# 出口方向雪弗龙
	var dirv := (end - start).normalized()
	var base := mid.lerp(end, 0.62)
	var tip := base + dirv * 6.0
	var perp := Vector2(-dirv.y, dirv.x)
	node.draw_colored_polygon(
		PackedVector2Array([tip, base + perp * 4.2, base - perp * 4.2]),
		CHEVRON_COLOR
	)

## 小箭头尖（T 支路/供给指向机器时用）
static func _draw_tip(node: CanvasItem, base: Vector2, dir: Vector2, color: Color, size: float) -> void:
	var tip := base + dir.normalized() * size
	var perp := Vector2(-dir.y, dir.x)
	node.draw_colored_polygon(
		PackedVector2Array([tip, base + perp * size * 0.7, base - perp * size * 0.7]),
		color
	)

## 四方向偏移（喂入/抽取扫描用）
const DIR_OFFSETS_ALL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
