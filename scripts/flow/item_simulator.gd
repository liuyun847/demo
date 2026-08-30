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
##
## 0 格贴脸直传（面传输）：机器 A 的输出口恰好是机器 B 的本体格，且 B 有输入口
## 正对 A（双向端口对齐）时，物品直接经"面槽"（ItemGrid.edge_slots）传递——
## 不落在任何网格格上（机器本体格永不持有网格物品），槽满则 A 背压等待。
## 不对齐（B 无正对 A 的输入口）时维持旧语义：输出被机器本体格堵住 → 等待。
## 面槽键=生产者格，值={item, front}；事件以 "face"（生产者→消费者的偏移）标注
## 面位置，渲染层定位到共享边中点。
##
## 垃圾桶：两类输入——①传送带把物品推进垃圾桶本体格（本体格可停靠、不进
## machine_cells 守卫），机器阶段销毁自身格物品；②贴脸机器（数字源/应用器/
## 分流器等输出口正对垃圾桶）经面槽投递，垃圾桶消费共享边物品。不从旁格主动
## 吸取（带格/端口格上的物品不会被销毁，端口格也不可停靠——"隔空吸取"被禁止）。

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
	# 机器自身格子永不放网格物品（移动阶段守卫）
	# 例外1：传送带+分流器一体建筑——其格即传送带，允许上游带把物品推入/机器输出
	# 落到其上，由分流器在机器阶段读取本格物品后分流（不进 machine_cells 守卫）。
	# 例外2：垃圾桶——本体格可停靠，传送带把物品推进来即被销毁（不进守卫）。
	# 先收集全部机器格再触发机器：机器阶段的输出/落点也要避开机器本体格，
	# 否则相邻机器"贴脸"放置（如数字源出口正对应用器）会把物品生成/推进对方
	# 本体格——该格无人读取、移动阶段又有 machine_cells 守卫禁止进入，物品永久卡死。
	# （0 格贴脸且端口对齐时走面槽直传，见 _deliver_output；不对齐仍按"输出被占"等待。）
	var machine_cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		var data: BuildingData = buildings[cell] as BuildingData
		if data != null and MachineSpec.is_machine(data.building_type):
			if not MachineSpec.is_belt_splitter(data.building_type) \
					and MachineSpec.get_kind(data.building_type) != MachineSpec.KIND_TRASH:
				machine_cells[cell] = true
	for cell: Vector2i in cells:
		var data: BuildingData = buildings[cell] as BuildingData
		if data != null and MachineSpec.is_machine(data.building_type):
			_fire_machine(buildings, data, grid, cell, events, machine_cells)
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
			# "传送带+分流器"一体建筑：自身格即传送带（可停靠/物品沿带流入）；
			# 端口格不加入停靠——四向含上游方向，若可停靠则上游带会把物品推进到
			# 上游方向端口格，而一体建筑输入排除上游方向（物品应沿带流入自身格），
			# 物品将永久卡死（原"后格不接收"回归语义；非上游方向的物品由带子
			# 顺带抽取/分流器轮询读取，不需要端口格停靠位）
			if MachineSpec.is_belt_splitter(data.building_type):
				dock[cell] = true
				continue
			# 垃圾桶：本体格可停靠（传送带把物品推进来即销毁——"传送带输入"路径），
			# 端口格不加入停靠——垃圾桶不从旁格主动吸取（"隔空吸取"被禁止），
			# 若旁格可停靠，带子会把物品推到旁格而垃圾桶不销毁，造成卡死
			if MachineSpec.get_kind(data.building_type) == MachineSpec.KIND_TRASH:
				dock[cell] = true
				continue
			for off: Vector2i in MachineSpec.get_ins(data.building_type, data.direction):
				dock[cell + off] = true
			for off: Vector2i in MachineSpec.get_outs(data.building_type, data.direction):
				dock[cell + off] = true
	return dock

# ---------- 机器触发 ----------

static func _fire_machine(buildings: Dictionary, data: BuildingData, grid: ItemGrid, cell: Vector2i, events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
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
			_fire_num_source(buildings, grid, cell, events, machine_cells)
		MachineSpec.KIND_TRASH:
			# 垃圾桶两类输入（每 tick 至多销毁 1 个，优先级如上）：
			#   1. 自身格物品（传送带把物品推进垃圾桶本体格——本体格可停靠、
			#      不进 machine_cells 守卫，物品送入即销毁；这是"传送带输入"路径）
			#   2. 四邻面槽投递物（贴脸机器输出口正对垃圾桶时 0 格直传，压到
			#      共享边；这是"机器投递输入"路径）
			# 不接受的：旁格（带格/端口格）上的网格物品——垃圾桶不从旁格主动
			# 吸取（"隔空吸取"被禁止），物品必须实际进入垃圾桶格或被贴脸投递。
			# 面槽取物必须走专用路径（不得复用 _consume_input/_take_input 的网格
			# 优先分支）：旁格若是一体建筑（传送带+分流器），该格可同时持有网格
			# 物品与面槽物品，网格优先会误销毁网格物品并把面槽投递物永久搁置。
			# 注意：循环变量不能叫 dir（与上方 var dir 局部变量遮蔽冲突，解析错误）
			var own_item: Item = grid.take_item(cell)
			if own_item != null:
				events.append({"kind": "despawn", "at": cell, "item": own_item})
			else:
				for scan_dir: int in GROUP_ORDER:
					var in_cell: Vector2i = cell + MachineSpec.dir_to_offset(scan_dir)
					var slot: Dictionary = grid.get_edge(in_cell)
					if slot.is_empty() or slot.get("front", Vector2i.ZERO) != cell - in_cell:
						continue
					var item: Item = grid.take_edge(in_cell)
					if item == null:
						continue
					events.append({"kind": "despawn", "at": in_cell, "face": slot["front"], "item": item})
					break
		MachineSpec.KIND_APPLIER:
			_fire_applier(buildings, grid, cell, ins, outs, events, machine_cells)
		MachineSpec.KIND_SPLITTER:
			_fire_splitter(buildings, data, grid, cell, ins, outs, events, machine_cells)
		MachineSpec.KIND_BELT_SPLITTER:
			_fire_belt_splitter(buildings, data, grid, cell, outs, events, machine_cells)
		# 未知 kind：惰性忽略（防御）

## 数字源（无方向）：每个 tick 按固定优先级 北→东→南→西 扫描四邻，产出到第一个
## 可投递目标：相邻传送带/一体建筑空格（→ 网格格）或贴脸对齐机器（输入口正对源，
## → 面槽直传）。空地/未对齐机器直接跳过（不产到空地，机器本体格守卫不变）。
## 全部不可投递 = 背压等待；一个方向被占不影响其他方向；物品永不丢失。
static func _fire_num_source(buildings: Dictionary, grid: ItemGrid, cell: Vector2i, events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	for dir: int in MachineSpec.SOURCE_OUTPUT_ORDER:
		var target: Vector2i = cell + MachineSpec.dir_to_offset(dir)
		var t_data: BuildingData = buildings.get(target) as BuildingData
		if t_data == null:
			continue  # 空地不产（无接收方）
		if MachineSpec.is_belt(t_data.building_type) or MachineSpec.is_belt_splitter(t_data.building_type):
			pass  # 带子/一体建筑格：物品落到格上（一体建筑格即传送带，允许）
		elif MachineSpec.is_machine(t_data.building_type):
			# 贴脸机器：仅当输入口正对源时走面槽直传（与 _out_available 对齐判定一致）
			if not MachineSpec.get_ins(t_data.building_type, t_data.direction).has(cell - target):
				continue
		else:
			continue
		if _deliver_output(buildings, grid, cell, target, Item.num(1), events, machine_cells):
			return

## 应用器：2入1出，输入口角色固定——数据口(ins[0])只收数字，操作口(ins[1])收
## 操作物品（按注册表应用）或数字 n（视为 "+n"，结果=数据+n）。任一输入缺失、
## 数据口非数字、输出不可投递（被占/对齐面槽满）均积压等待；两输入同时消耗。
static func _fire_applier(buildings: Dictionary, grid: ItemGrid, cell: Vector2i, ins: Array[Vector2i], outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	var data_item: Item = _get_input(buildings, grid, ins[MachineSpec.APPLIER_IN_DATA], cell)
	var op_item: Item = _get_input(buildings, grid, ins[MachineSpec.APPLIER_IN_OP], cell)
	if data_item == null or op_item == null:
		return
	if not data_item.is_num():
		return  # 数据口只收数字：类型不匹配，等待
	if not _out_available(buildings, grid, cell, outs[0], machine_cells):
		return  # 输出不可投递（被占/对齐面槽满）：等待
	var result: int
	if op_item.is_op():
		result = OpRegistry.apply(op_item.value, data_item.value)
	else:
		result = data_item.value + op_item.value  # 数字 n = "+n"（int64 溢出回绕）
	_consume_input(buildings, grid, ins[MachineSpec.APPLIER_IN_DATA], cell, events)
	_consume_input(buildings, grid, ins[MachineSpec.APPLIER_IN_OP], cell, events)
	_deliver_output(buildings, grid, cell, outs[0], Item.num(result), events, machine_cells)

## 四向分流器：4 个方向口完全对称（不区分输入输出），每 tick 至多处理 1 个物品。
## 输入：从 splitter_in_phase 起轮询扫描 4 方向（E→S→W→N），取第一个可读位置
## （网格格物品或贴脸机器面槽，见 _get_input）。
## 输出：从 splitter_phase 起轮询扫描 4 方向，取第一个"条件匹配 + 有效承接 + 可投递"方向：
##   - 方向条件：splitter_filters 按输出方向独立设置（空=无条件放行；不匹配的方向
##     跳过不阻塞其他方向，全部不匹配 = 背压等待，物品不丢）
##   - 有效承接：目标格是带子/一体建筑格，或贴脸对齐机器（面槽直传），或是其他
##     机器（非一体）的输入口端口格（→ 网格格停靠后由机器顺带抽取）
##   - 排除回流：不投回本 tick 输入方向（避免同一物品被自己反复读取）
##   - 可投递：复用 _out_available（格空/面槽空、非机器本体格）
## 投递成功才推进两个相位（输出方向+1、输入方向+1）；全部不可投 = 背压等待（物品不丢）。
## 空地方向一律跳过：只投有承接方的方向，物品绝不落空地。
static func _fire_splitter(buildings: Dictionary, data: BuildingData, grid: ItemGrid, cell: Vector2i, _ins: Array[Vector2i], _outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	var found := _find_input(buildings, data, grid, cell, false)
	var in_dir: int = found[0]
	var item: Item = found[1]
	if in_dir < 0:
		return  # 无输入：等待
	var out_dir := _pick_out_dir(buildings, data, grid, cell, in_dir, item, machine_cells, false)
	if out_dir < 0:
		return  # 无可投方向：背压等待（不读输入、不动相位）
	var ins_cell: Vector2i = cell + MachineSpec.dir_to_offset(in_dir)
	var out_pos: Vector2i = cell + MachineSpec.dir_to_offset(out_dir)
	_move_input(buildings, grid, ins_cell, cell, out_pos, events)
	data.splitter_phase = (out_dir + 1) % 4
	data.splitter_in_phase = (in_dir + 1) % 4
	data.last_out_dir = out_dir

## 传送带+分流器一体：输入 = 本格优先（物品由上游带推入/本就停在带上），否则轮询
## 4 方向（同普通分流器）；输出为 4 向轮询，额外排除"上游方向"（相邻带子指向本格的
## 边）与本 tick 输入方向，防止物品被投回上游带子造成回流循环。
## 方向条件（splitter_filters）与普通分流器一致，自身格流入的物品同样受约束。
## 本格不做传送带移动处理（非 belt 条目）。
static func _fire_belt_splitter(buildings: Dictionary, data: BuildingData, grid: ItemGrid, cell: Vector2i, _outs: Array[Vector2i], events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> void:
	var item: Item = _get_input(buildings, grid, cell, cell)
	var from_own := item != null
	var in_dir := -1
	if not from_own:
		var found := _find_input(buildings, data, grid, cell, true)
		in_dir = found[0]
		item = found[1]
		if in_dir < 0:
			return
	var out_dir := _pick_out_dir(buildings, data, grid, cell, in_dir, item, machine_cells, true)
	if out_dir < 0:
		return  # 无可投方向：背压等待
	var out_pos: Vector2i = cell + MachineSpec.dir_to_offset(out_dir)
	if from_own:
		_move_input(buildings, grid, cell, cell, out_pos, events)
	else:
		var ins_cell: Vector2i = cell + MachineSpec.dir_to_offset(in_dir)
		_move_input(buildings, grid, ins_cell, cell, out_pos, events)
	data.splitter_phase = (out_dir + 1) % 4
	# 自身格读取时不推进输入相位：带子流入的连续物品始终优先（自身格是唯一输入口），
	# 外部端口仅在自身格空闲时轮询——若推进相位会污染"下一次从哪个外部方向轮询"的记忆
	if not from_own:
		data.splitter_in_phase = (in_dir + 1) % 4
	data.last_out_dir = out_dir

## 轮询扫描 4 个输入方向（从 splitter_in_phase 起 E→S→W→N），返回第一个可读的
## [方向, 物品]（网格格物品或贴脸机器面槽物品）；无可读返回 [-1, null]。
## belt_splitter=true 时跳过自身格（自身格由调用方优先处理）并排除"上游方向"：
## 上游带把物品自然推进自身格，若主动从上游方向抽取会打破带子逐格流动（物品跳过
## 自身格直接跳输出，与输出排除上游方向对称，防回流）。
## 另跳过"上一轮输出方向"（data.last_out_dir）：物品投出后若停在输出端口格（下游
## 积压），不被输入轮询读回——否则物品在端口格间循环搬运永不前进。
## 注意：仅在"投递过"之后应用跳过——初始态（last_out_dir=-1）时若反推
## (phase-1+4)%4 会得北并跳过，导致北向输入在默认朝向下永久死锁（北是扫描
## 最后一项，扫到即被跳过、相位永不推进）；且一体建筑自身格投递后 phase 可
## 回绕 0 且 in_phase 保持 0（自身格读取不推进输入相位），相位反推会误判
## "从未投递"——故用独立字段 last_out_dir 记录，投递时显式写入。
## 跳过仅作用于输入侧轮询；输出侧不受影响（物品是否可投由 _pick_out_dir 的
## 被占/背压判定自然处理，不依赖本字段）。last_out_dir 是纯运行时记忆，撤销/
## 粘贴/存档恢复后回到 -1：此时防循环保护短暂失效（最多一两次扫描），下一次
## 投递即重新写入自愈，不构成持久错误。
static func _find_input(buildings: Dictionary, data: BuildingData, grid: ItemGrid, cell: Vector2i, belt_splitter: bool) -> Array:
	var upstream: Array[int] = []
	if belt_splitter:
		upstream = _upstream_dirs(buildings, cell)
	var last_out: int = data.last_out_dir  # -1 = 从未投递，不跳过任何方向
	for i in range(4):
		var dir: int = (data.splitter_in_phase + i) % 4
		if upstream.has(dir):
			continue  # 一体建筑不从上游方向抽取（物品沿带自然流入自身格）
		if last_out >= 0 and dir == last_out:
			continue  # 不读回自己刚投出的物品（防循环搬运）
		var input_cell: Vector2i = cell + MachineSpec.dir_to_offset(dir)
		var item: Item = _get_input(buildings, grid, input_cell, cell)
		if item != null:
			return [dir, item]
	return [-1, null]

## 轮询扫描 4 个输出方向（从 splitter_phase 起 E→S→W→N），返回第一个
## "方向条件匹配 + 有效承接 + 可投递"方向；排除回流方向（输入方向 / 一体建筑上游
## 方向）。条件不匹配与被占同级：跳过不阻塞，全部不匹配返回 -1（背压等待）。
static func _pick_out_dir(buildings: Dictionary, data: BuildingData, grid: ItemGrid, cell: Vector2i, in_dir: int, item: Item, machine_cells: Dictionary[Vector2i, bool], belt_splitter: bool) -> int:
	var upstream: Array[int] = []
	if belt_splitter:
		upstream = _upstream_dirs(buildings, cell)
	for i in range(4):
		var dir: int = (data.splitter_phase + i) % 4
		if dir == in_dir:
			continue  # 不投回输入方向（防同一物品回流自读）
		if upstream.has(dir):
			continue  # 一体建筑不投回上游带（防回流循环）
		if not _cond_matches(data.splitter_filters, dir, item):
			continue  # 方向条件不匹配：跳过（不阻塞其他方向，全部不匹配=背压）
		var target: Vector2i = cell + MachineSpec.dir_to_offset(dir)
		if not _is_receiving_out_cell(buildings, target):
			continue  # 空地/无承接方向：跳过（物品不落空地）
		if not _out_available(buildings, grid, cell, target, machine_cells):
			continue  # 被占/面槽满：跳过（不阻塞）
		return dir
	return -1

## 方向条件匹配：splitter_filters[dir] 为空字典 = 无条件放行；
## kind=op 按操作 id 相等匹配；kind=num 按 cmp 与 value 比较。
## 数组尺寸异常（旧存档/脏数据）按全无条件处理（防御）。
static func _cond_matches(filters: Array, dir: int, item: Item) -> bool:
	if filters.size() != 4:
		return true
	var cond: Variant = filters[dir]
	if not (cond is Dictionary) or (cond as Dictionary).is_empty():
		return true
	return _matches(cond as Dictionary, item)

## 目标格是否有承接方（物品可停靠/被继续消费）：
## - 带子 / 一体建筑格：物品落到格上继续流动（一体建筑读自身格）
## - 机器（非一体）本体格：统一返回 true，能否投递由 _out_available 做贴脸对齐判定
## - 其他机器（非分流器）输入口端口格（目标格无建筑）：物品停靠后被机器顺带抽取
## - 分流器自身端口格 / 空地 / 未对齐机器：不承接（投到自己端口格=落空地无人消费卡死）
static func _is_receiving_out_cell(buildings: Dictionary, target: Vector2i) -> bool:
	var t_data: BuildingData = buildings.get(target) as BuildingData
	if t_data == null:
		# 无建筑格：仅当它是某台其他机器（非分流器）的输入口端口格时才承接（顺带抽取）
		for cell: Vector2i in buildings.keys():
			var data: BuildingData = buildings[cell] as BuildingData
			if data == null or not MachineSpec.is_machine(data.building_type):
				continue
			if MachineSpec.is_belt_splitter(data.building_type):
				continue  # 一体建筑输入=自身格，其 ins 端口不承接
			if MachineSpec.get_kind(data.building_type) == MachineSpec.KIND_SPLITTER:
				continue  # 分流器自身端口格不承接（投过去无人消费）
			if MachineSpec.get_kind(data.building_type) == MachineSpec.KIND_TRASH:
				continue  # 垃圾桶端口格不承接网格物品（只接受贴脸投递面槽，投到端口格无人消费）
			if MachineSpec.get_ins(data.building_type, data.direction).has(target - cell):
				return true
		return false
	if MachineSpec.is_belt(t_data.building_type) or MachineSpec.is_belt_splitter(t_data.building_type):
		return true
	if MachineSpec.is_machine(t_data.building_type):
		return true  # 贴脸对齐判定由 _out_available 承担
	return false

## 一体建筑的上游方向：相邻带子/一体建筑迎向本格的边（同 BeltConnection feed 判定）。
## 输出不得投回这些方向（否则物品从上游带刚流入又被打回，形成回流循环）。
static func _upstream_dirs(buildings: Dictionary, cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n: Vector2i = cell + off
		var n_data: BuildingData = buildings.get(n) as BuildingData
		if n_data == null:
			continue
		if MachineSpec.is_belt(n_data.building_type) or MachineSpec.is_belt_splitter(n_data.building_type):
			if n_data.direction == BeltConnection.offset_to_dir(-off):
				result.append(BeltConnection.offset_to_dir(off))
	return result

## 方向条件谓词：kind=op 时按操作 id 相等匹配（忽略 cmp）；kind=num 时按 cmp 与 value 比较
static func _matches(cond: Dictionary, item: Item) -> bool:
	if cond.get("kind", "") == "op":
		return item.is_op() and item.value == int(cond.get("value", -1))
	if not item.is_num():
		return false
	var value := int(cond.get("value", 0))
	match str(cond.get("cmp", "gt")):
		"eq":
			return item.value == value
		"ne":
			return item.value != value
		"lt":
			return item.value < value
		_:
			return item.value > value

# ---------- 输入读取 / 面传输 ----------

## 面槽物品判定：cell 是机器格且其面槽物品正对 consumer_cell（0 格贴脸直传）。
## 仅供"投递输入"类消费方（垃圾桶）与 _get_input 的面槽分支共享，防判定漂移。
static func _edge_item(buildings: Dictionary, grid: ItemGrid, cell: Vector2i, consumer_cell: Vector2i) -> Item:
	var producer: BuildingData = buildings.get(cell) as BuildingData
	if producer != null and MachineSpec.is_machine(producer.building_type):
		var slot: Dictionary = grid.get_edge(cell)
		if not slot.is_empty() and slot.get("front", Vector2i.ZERO) == consumer_cell - cell:
			return slot.get("item") as Item
	return null

## 读取输入端物品：网格格或"面槽"（0 格贴脸直传，物品压在共享边）。
## consumer_cell 用于核对面槽方向：物品必须来自正对自己的面。
## 生产者可为任意机器（含传送带+分流器一体建筑——其输出口也可贴脸直传；
## 读侧不排除一体建筑，由目标侧检查（_out_available/_deliver_output）承担
## "一体建筑不能作为面消费目标"的语义：它被当作带子，输出落到其格=网格物品）。
static func _get_input(buildings: Dictionary, grid: ItemGrid, cell: Vector2i, consumer_cell: Vector2i) -> Item:
	if grid.has_item(cell):
		return grid.get_item(cell)
	return _edge_item(buildings, grid, cell, consumer_cell)

## 取走输入端物品（网格格或面槽），不产生事件；调用方按消费语义发事件。
## 返回 [item, from_face]：from_face 非零表示取自面槽（物品原位置在共享边上）。
static func _take_input(buildings: Dictionary, grid: ItemGrid, cell: Vector2i, consumer_cell: Vector2i) -> Array:
	if grid.has_item(cell):
		return [grid.take_item(cell), Vector2i.ZERO]
	var producer: BuildingData = buildings.get(cell) as BuildingData
	if producer != null and MachineSpec.is_machine(producer.building_type):
		var slot: Dictionary = grid.get_edge(cell)
		if not slot.is_empty() and slot.get("front", Vector2i.ZERO) == consumer_cell - cell:
			var face: Vector2i = slot["front"]
			return [grid.take_edge(cell), face]
	return [null, Vector2i.ZERO]

## 消费输入：取走物品并发出 despawn 事件（位置=网格格或面槽共享边）。
static func _consume_input(buildings: Dictionary, grid: ItemGrid, cell: Vector2i, consumer_cell: Vector2i, events: Array[Dictionary]) -> void:
	var taken: Array = _take_input(buildings, grid, cell, consumer_cell)
	var item: Item = taken[0] as Item
	if item == null:
		return
	var face: Vector2i = taken[1]
	if face == Vector2i.ZERO:
		events.append({"kind": "despawn", "at": cell, "item": item})
	else:
		events.append({"kind": "despawn", "at": cell, "face": face, "item": item})

## 输出目标可投递性：常规格（空格且非机器本体格），或贴面对面槽（目标机器有
## 输入口正对本生产者且面槽空）。不对齐的机器本体格视为"输出被占"。
static func _out_available(buildings: Dictionary, grid: ItemGrid, producer_cell: Vector2i, out_cell: Vector2i, machine_cells: Dictionary[Vector2i, bool]) -> bool:
	var target: BuildingData = buildings.get(out_cell) as BuildingData
	if target != null and MachineSpec.is_machine(target.building_type) and not MachineSpec.is_belt_splitter(target.building_type):
		# 0 格贴脸：仅当目标机器有输入口正对本生产者时直传（面槽空则可投）
		if not MachineSpec.get_ins(target.building_type, target.direction).has(producer_cell - out_cell):
			return false
		return not grid.has_edge(producer_cell)
	if grid.has_item(out_cell) or machine_cells.has(out_cell):
		return false
	return true

## 从输入移动物品到输出（网格格/面槽 → 网格格/面槽），发出 move 事件。
## 调用方需先经 _get_input + _out_available 确认可读可投。
static func _move_input(buildings: Dictionary, grid: ItemGrid, ins_cell: Vector2i, consumer_cell: Vector2i, out_cell: Vector2i, events: Array[Dictionary]) -> void:
	var taken: Array = _take_input(buildings, grid, ins_cell, consumer_cell)
	var item: Item = taken[0] as Item
	if item == null:
		return
	_move_input_impl(buildings, grid, ins_cell, consumer_cell, out_cell, item, taken[1], events)

## 内部实现：把已取走的 item 投到 out（网格格或面槽），并生成 move 事件。
static func _move_input_impl(buildings: Dictionary, grid: ItemGrid, ins_cell: Vector2i, consumer_cell: Vector2i, out_cell: Vector2i, item: Item, from_face: Vector2i, events: Array[Dictionary]) -> void:
	var target: BuildingData = buildings.get(out_cell) as BuildingData
	if target != null and MachineSpec.is_machine(target.building_type) and not MachineSpec.is_belt_splitter(target.building_type):
		# 贴脸直传：写入面槽（调用方已确认槽空）
		var face_off: Vector2i = out_cell - consumer_cell
		grid.set_edge(consumer_cell, item, face_off)
		if from_face == Vector2i.ZERO:
			events.append({"kind": "move", "from": ins_cell, "to": consumer_cell, "to_face": face_off, "item": item})
		else:
			events.append({"kind": "move", "from": ins_cell, "from_face": from_face, "to": consumer_cell, "to_face": face_off, "item": item})
		return
	grid.set_item(out_cell, item)
	if from_face == Vector2i.ZERO:
		events.append({"kind": "move", "from": ins_cell, "to": out_cell, "item": item})
	else:
		events.append({"kind": "move", "from": ins_cell, "from_face": from_face, "to": out_cell, "item": item})

## 投递输出：目标为可停靠/可收格则写入网格格；目标为贴面对齐机器本体格则写入
## 面槽（0 格直传）；否则返回 false（输出被占，调用方背压等待）。成功即发 spawn 事件。
static func _deliver_output(buildings: Dictionary, grid: ItemGrid, producer_cell: Vector2i, out_cell: Vector2i, item: Item, events: Array[Dictionary], machine_cells: Dictionary[Vector2i, bool]) -> bool:
	var target: BuildingData = buildings.get(out_cell) as BuildingData
	if target != null and MachineSpec.is_machine(target.building_type) and not MachineSpec.is_belt_splitter(target.building_type):
		# 0 格贴脸：仅当目标机器有输入口正对本生产者时直传（面槽满则等待）
		if not MachineSpec.get_ins(target.building_type, target.direction).has(producer_cell - out_cell):
			return false
		if grid.has_edge(producer_cell):
			return false
		var face_off: Vector2i = out_cell - producer_cell
		grid.set_edge(producer_cell, item, face_off)
		events.append({"kind": "spawn", "at": producer_cell, "face": face_off, "item": item})
		return true
	if grid.has_item(out_cell) or machine_cells.has(out_cell):
		return false
	grid.set_item(out_cell, item)
	events.append({"kind": "spawn", "at": out_cell, "item": item})
	return true

# ---------- 基础操作 ----------

static func _move_item(from_pos: Vector2i, to_pos: Vector2i, grid: ItemGrid, events: Array[Dictionary]) -> void:
	var item: Item = grid.take_item(from_pos)
	grid.set_item(to_pos, item)
	events.append({"kind": "move", "from": from_pos, "to": to_pos, "item": item})
