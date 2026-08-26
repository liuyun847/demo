class_name ItemSimulator
extends RefCounted

## 物品流模拟器（纯逻辑，无节点依赖，可直接单元测试）。
## 每 tick 两个阶段：
##   1. 机器阶段：按格坐标排序逐个触发机器（确定性）；输入到齐且输出格空才触发，
##      不满足条件 = 背压等待（物品永不丢失，除非进垃圾桶）。
##   2. 移动阶段：传送带按方向分组（N→E→S→W 固定顺序），组内下游先处理，
##      保证同向链整体推进；分流的竞争由组顺序 + 格排序决定，确定性且不丢物品。
## 事件数组供渲染层做位置插值：{kind: "spawn"|"despawn"|"move", ...}
## 同步路径调用 tick()；分帧路径分别调用 machine_phase() / move_phase()。

# 方向组处理顺序（固定，保证确定性）
const GROUP_ORDER: Array[int] = [
	MachineSpec.DIR_N, MachineSpec.DIR_E, MachineSpec.DIR_S, MachineSpec.DIR_W,
]

## 同步完整 tick（测试/低延迟路径）
static func tick(buildings: Dictionary, grid: ItemGrid) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var machine_cells: Dictionary[Vector2i, bool] = machine_phase(buildings, grid, events)
	move_phase(buildings, machine_cells, grid, events)
	return events

## 阶段 1：机器。返回 {events, machine_cells}（machine_cells 供移动阶段守卫）
static func machine_phase(buildings: Dictionary, grid: ItemGrid, events: Array[Dictionary]) -> Dictionary[Vector2i, bool]:
	var cells: Array[Vector2i] = []
	cells.assign(buildings.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	# 机器自身格子永不放物品（移动阶段守卫）
	# 例外：传送带+分流器一体建筑——其格即传送带，允许上游带把物品推入，
	# 由分流器在机器阶段读取本格物品后分流（不进 machine_cells 守卫）。
	# 先收集全部机器格再触发机器：机器阶段的输出/落点也要避开机器本体格，
	# 否则相邻机器"贴脸"放置（如数字源出口正对应用器）会把物品生成/推进对方
	# 本体格——该格无人读取、移动阶段又有 machine_cells 守卫禁止进入，物品永久卡死。
	var machine_cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		var data: BuildingData = buildings[cell] as BuildingData
		if data != null and MachineSpec.is_machine(data.building_type):
			if not MachineSpec.is_belt_splitter(data.building_type):
				machine_cells[cell] = true
	for cell: Vector2i in cells:
		var data: BuildingData = buildings[cell] as BuildingData
		if data != null and MachineSpec.is_machine(data.building_type):
			_fire_machine(data, grid, cell, events, machine_cells)
	return machine_cells

## 阶段 2：传送带移动
static func move_phase(buildings: Dictionary, machine_cells: Dictionary[Vector2i, bool], grid: ItemGrid, events: Array[Dictionary]) -> void:
	var dock_cells := collect_dock_cells(buildings)
	var cells_by_dir: Dictionary = {
		MachineSpec.DIR_N: [],
		MachineSpec.DIR_E: [],
		MachineSpec.DIR_S: [],
		MachineSpec.DIR_W: [],
	}
	for cell: Vector2i in buildings.keys():
		var data: BuildingData = buildings[cell] as BuildingData
		if data != null and MachineSpec.is_belt(data.building_type):
			(cells_by_dir[data.direction] as Array).append(cell)
	for dir: int in GROUP_ORDER:
		var cells: Array = cells_by_dir[dir]
		# 组内排序：下游优先（让位链：先移动目标格，上游才能跟进）
		match dir:
			MachineSpec.DIR_N:
				cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					if a.y != b.y:
						return a.y < b.y
					return a.x < b.x)
			MachineSpec.DIR_E:
				cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					if a.x != b.x:
						return a.x > b.x
					return a.y < b.y)
			MachineSpec.DIR_S:
				cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					if a.y != b.y:
						return a.y > b.y
					return a.x < b.x)
			MachineSpec.DIR_W:
				cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					if a.x != b.x:
						return a.x < b.x
					return a.y < b.y)
		for cell: Vector2i in cells:
			if not grid.has_item(cell):
				continue
			var target: Vector2i = cell + MachineSpec.dir_to_offset(dir)
			if machine_cells.has(target):
				continue  # 机器自身格不放物品
			if not dock_cells.has(target):
				continue  # 空地不放物品：物品只能在传送带/机器端口格上停靠
			if grid.has_item(target):
				continue
			_move_item(cell, target, grid, events)

## 可停靠格集合：所有传送带格 + 所有机器的输入/输出端口格（世界坐标，含旋转）。
## 物品只能停在这些格子上；传送到空地/未知格一律背压等待，保证数字不落在空地上。
## 公共静态：删除建筑清理物品时复用同一判定（避免两处规则漂移）。
static func collect_dock_cells(buildings: Dictionary) -> Dictionary[Vector2i, bool]:
	var dock: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in buildings.keys():
		var data: BuildingData = buildings[cell] as BuildingData
		if data == null:
			continue
		if MachineSpec.is_belt(data.building_type):
			dock[cell] = true
		elif MachineSpec.is_machine(data.building_type):
			# "传送带+分流器"一体建筑：自身格即传送带（可停靠/物品流入）；
			# 其输入是自身格而非后格——ins 端口仅为视觉箭头，不加入停靠，
			# 否则上游带把物品推入后格后无人消费，形成永久死停车位（背压断链）
			if MachineSpec.is_belt_splitter(data.building_type):
				dock[cell] = true
				for off: Vector2i in MachineSpec.get_outs(data.building_type, data.direction):
					dock[cell + off] = true
				continue
			for off: Vector2i in MachineSpec.get_ins(data.building_type, data.direction):
				dock[cell + off] = true
			for off: Vector2i in MachineSpec.get_outs(data.building_type, data.direction):
				dock[cell + off] = true
	return dock

# ---------- 机器触发 ----------

static func _fire_machine(data: BuildingData, grid: ItemGrid, cell: Vector2i, events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	var kind: String = MachineSpec.get_kind(data.building_type)
	var dir: int = data.direction
	# 端口偏移 -> 世界坐标（机器格 + 旋转后的偏移）
	var ins: Array[Vector2i] = []
	for off: Vector2i in MachineSpec.get_ins(data.building_type, dir):
		ins.append(cell + off)
	var outs: Array[Vector2i] = []
	for off: Vector2i in MachineSpec.get_outs(data.building_type, dir):
		outs.append(cell + off)
	match kind:
		MachineSpec.KIND_NUM_SOURCE:
			_spawn_if_empty(grid, outs[0], Item.num(1), events, machine_cells)
		MachineSpec.KIND_TRASH:
			if not ins.is_empty() and grid.has_item(ins[0]):
				_despawn(ins[0], grid, events)
		MachineSpec.KIND_APPLIER:
			_fire_applier(data, grid, ins, outs, events, machine_cells)
		MachineSpec.KIND_SPLITTER:
			_fire_splitter(data, grid, ins, outs, events, machine_cells)
		MachineSpec.KIND_BELT_SPLITTER:
			_fire_belt_splitter(data, grid, cell, outs, events, machine_cells)
		MachineSpec.KIND_FILTER:
			_fire_filter(data, grid, ins, outs, events, machine_cells)
		# 未知 kind：惰性忽略（防御）

## 应用器：2入1出，(op, data) -> data∘op 的结果。
## 两个输入必须一 op 一 num 且输出格空，否则积压等待。
static func _fire_applier(_data: BuildingData, grid: ItemGrid, ins: Array[Vector2i], outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	var a: Item = grid.get_item(ins[0])
	var b: Item = grid.get_item(ins[1])
	if a == null or b == null:
		return
	if a.is_op() == b.is_op():
		return  # 两个同类型：类型不匹配，等待
	if grid.has_item(outs[0]) or machine_cells.has(outs[0]):
		return  # 输出格被占（含机器本体格）：等待
	var op_item: Item = a if a.is_op() else b
	var num_item: Item = b if a.is_op() else a
	var result := OpRegistry.apply(op_item.value, num_item.value)
	_despawn(ins[0], grid, events)
	_despawn(ins[1], grid, events)
	_spawn_at(grid, outs[0], Item.num(result), events)

## 分流器：1入2出，按交替位选择出口（0=front，1=left），送达后翻转
static func _fire_splitter(data: BuildingData, grid: ItemGrid, ins: Array[Vector2i], outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	if ins.is_empty() or not grid.has_item(ins[0]):
		return
	var out_pos: Vector2i = outs[0] if data.splitter_phase == 0 else outs[1]
	if grid.has_item(out_pos) or machine_cells.has(out_pos):
		return  # 出口被占（含机器本体格）：等待（不清空交替位）
	_move_item(ins[0], out_pos, grid, events)
	data.splitter_phase = 1 - data.splitter_phase

## 传送带+分流器一体：输入 = 本格（物品由上游带推入/本就停在带上），
## 按交替位把本格物品送到前口（outs[0]）或左口（outs[1]），送达后翻转。
## 与普通分流器唯一差异：读取自身格而非后格；本格不做传送带移动处理（非 belt 条目）。
static func _fire_belt_splitter(data: BuildingData, grid: ItemGrid, cell: Vector2i, outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	if outs.is_empty() or not grid.has_item(cell):
		return
	var out_pos: Vector2i = outs[0] if data.splitter_phase == 0 else outs[1]
	if grid.has_item(out_pos) or machine_cells.has(out_pos):
		return  # 出口被占（含机器本体格）：等待（不清空交替位）
	_move_item(cell, out_pos, grid, events)
	data.splitter_phase = 1 - data.splitter_phase

## 筛选器：1入2出，匹配谓词走 front（通过），否则走 left（拒绝）
static func _fire_filter(data: BuildingData, grid: ItemGrid, ins: Array[Vector2i], outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	if ins.is_empty() or not grid.has_item(ins[0]):
		return
	var item: Item = grid.get_item(ins[0])
	var out_pos: Vector2i = outs[0] if _matches(data, item) else outs[1]
	if grid.has_item(out_pos) or machine_cells.has(out_pos):
		return  # 输出被占（含机器本体格）：等待
	_move_item(ins[0], out_pos, grid, events)

## 筛选器谓词：kind=op 时按操作 id 相等匹配（忽略 cmp）；kind=num 时按 cmp 与 value 比较
static func _matches(data: BuildingData, item: Item) -> bool:
	if data.filter_kind == "op":
		return item.is_op() and item.value == data.filter_value
	if not item.is_num():
		return false
	match data.filter_cmp:
		"eq":
			return item.value == data.filter_value
		"ne":
			return item.value != data.filter_value
		"lt":
			return item.value < data.filter_value
		_:
			return item.value > data.filter_value

# ---------- 基础操作 ----------

static func _move_item(from_pos: Vector2i, to_pos: Vector2i, grid: ItemGrid, events: Array[Dictionary]) -> void:
	var item: Item = grid.take_item(from_pos)
	grid.set_item(to_pos, item)
	events.append({"kind": "move", "from": from_pos, "to": to_pos, "item": item})

static func _spawn_if_empty(grid: ItemGrid, pos: Vector2i, item: Item, events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	if not grid.has_item(pos) and not machine_cells.has(pos):
		_spawn_at(grid, pos, item, events)

static func _spawn_at(grid: ItemGrid, pos: Vector2i, item: Item, events: Array[Dictionary]) -> void:
	grid.set_item(pos, item)
	events.append({"kind": "spawn", "at": pos, "item": item})

static func _despawn(pos: Vector2i, grid: ItemGrid, events: Array[Dictionary]) -> void:
	var item: Item = grid.take_item(pos)
	if item != null:
		events.append({"kind": "despawn", "at": pos, "item": item})