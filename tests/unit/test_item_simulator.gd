extends GutTest

## ItemSimulator 纯逻辑测试：不依赖节点/场景。

var _grid: ItemGrid = null
var _buildings: Dictionary = {}

func before_each() -> void:
	_grid = ItemGrid.new()
	_buildings = {}

func after_each() -> void:
	_grid = null
	_buildings = {}

func _bd(type_id: String, dir: int = MachineSpec.DIR_E, extra: Dictionary = {}) -> BuildingData:
	var d := BuildingData.new()
	d.building_type = type_id
	d.direction = dir
	for key: String in extra.keys():
		d.set(key, extra[key])
	return d

func _tick(times: int = 1) -> Array[Dictionary]:
	var all_events: Array[Dictionary] = []
	for i in range(times):
		all_events.append_array(ItemSimulator.tick(_buildings, _grid))
	return all_events

func _put(pos: Vector2i, item: Item) -> void:
	_grid.set_item(pos, item)

func _has_num(pos: Vector2i, value: int) -> bool:
	var it := _grid.get_item(pos)
	return it != null and it.is_num() and it.value == value

func _has_op(pos: Vector2i, op_id: int) -> bool:
	var it := _grid.get_item(pos)
	return it != null and it.is_op() and it.value == op_id

# ---------- 传送带 ----------

func test_belt_chain_moves_one_cell_per_tick() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "1 tick 后物品应前进 1 格")
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "2 tick 后物品应前进 2 格")
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "3 tick 后物品应停在带子末端（空地不接收）")
	assert_false(_grid.has_item(Vector2i(3, 0)), "物品不应离开带子落到空旷地面")

func test_belt_chain_moves_stops_at_belt_end() -> void:
	# 带子末端没有接收（空地）时物品应停在末端带子上，不流落到空地
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(1, 0), 1), "物品应停在带子末端等待，不落到空地")
	assert_false(_grid.has_item(Vector2i(2, 0)), "空地不应出现物品")

func test_belt_chain_empty_tail_moves_front_first() -> void:
	# 链尾有空格时整链同时推进（下游先让位；末端 (2,0) 补带子接收物品）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_put(Vector2i(1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "上游物品应跟进")
	assert_true(_has_num(Vector2i(2, 0), 2), "下游物品应推进到末端带子")

func test_belt_backpressure_blocks_chain() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_put(Vector2i(1, 0), Item.num(2))
	_put(Vector2i(2, 0), Item.num(3))  # 带子末端被占，堵住出口
	_tick()
	assert_true(_has_num(Vector2i(0, 0), 1), "出口被堵时整链背压不动")
	assert_true(_has_num(Vector2i(1, 0), 2))
	assert_true(_has_num(Vector2i(2, 0), 3))

func test_belt_full_ring_frozen() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_W)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)
	for cell: Vector2i in _buildings.keys():
		_put(cell, Item.num(1))
	_tick(3)
	for cell: Vector2i in _buildings.keys():
		assert_true(_has_num(cell, 1), "满环是合法积压稳态，物品不丢不移")

func test_belt_t_junction_priority_deterministic() -> void:
	# 东向带 A 与北向带 B 竞争进入 C 格（C 也是东向带）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)  # A
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)  # C
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)  # B
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)  # D 接收
	_buildings[Vector2i(3, 0)] = _bd(MachineSpec.T_BELT)  # 末端接收，防止流入空地
	_put(Vector2i(0, 0), Item.num(1))
	_put(Vector2i(1, 0), Item.num(2))
	_put(Vector2i(1, 1), Item.num(3))
	_tick(2)
	# 组顺序 N→E：B 永远落后于 E 组竞争（确定性饥饿）
	assert_true(_has_num(Vector2i(3, 0), 2), "C 的物品应持续推进并被送走")
	assert_true(_has_num(Vector2i(2, 0), 1), "A 的物品应跟进占据 C 格之前的带子")
	assert_true(_has_num(Vector2i(1, 1), 3), "B 的物品应原地等待（确定性）")

func test_belt_rotation() -> void:
	# 北向带：物品向上推进（(0,-1) 补带子接收）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 1), "北向带应向上推进")

# ---------- 源头 ----------

func test_num_source_produces_one_per_tick_with_receiver() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "源头产 1，带子送走")
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "下一 tick 源头再产 1")
	assert_true(_has_num(Vector2i(2, 0), 1), "前一个 1 被堵在带子末端")

func test_num_source_backpressure_stops_production() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_tick()
	_tick()
	assert_eq(_grid.count_items(), 1, "输出格被占时源头不再产出")

# ---------- 应用器 ----------

func test_applier_computes_op_on_num() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.op(OpRegistry.OP_ADD1))
	_put(Vector2i(0, 1), Item.num(1))
	var events := _tick()
	assert_true(_has_num(Vector2i(1, 0), 2), "1 + 1 = 2")
	assert_false(_grid.has_item(Vector2i(0, -1)), "输入应被消耗")
	assert_false(_grid.has_item(Vector2i(0, 1)))
	var despawn_count := 0
	for e: Dictionary in events:
		if e.kind == "despawn":
			despawn_count += 1
	assert_eq(despawn_count, 2)

func test_applier_inputs_interchangeable() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(3))
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_MUL2))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 6), "操作在任一输入口都应生效")

func test_applier_waits_for_second_input() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(1))
	_tick(2)
	assert_true(_has_num(Vector2i(0, -1), 1), "输入未到齐应积压等待")

func test_applier_type_mismatch_waits() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(1))
	_put(Vector2i(0, 1), Item.num(2))
	_tick(2)
	assert_true(_has_num(Vector2i(0, -1), 1), "两个数字无法配对，等待")
	assert_true(_has_num(Vector2i(0, 1), 2))

func test_applier_output_blocked_waits() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.op(OpRegistry.OP_ADD1))
	_put(Vector2i(0, 1), Item.num(1))
	_put(Vector2i(1, 0), Item.num(9))
	_tick(2)
	assert_true(_has_op(Vector2i(0, -1), OpRegistry.OP_ADD1), "输出被占时输入不被消耗")
	assert_true(_has_num(Vector2i(0, 1), 1))

# ---------- 分流器 ----------

func test_splitter_alternates() -> void:
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_put(Vector2i(-1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "第一次走 front 口")
	assert_eq(data.splitter_phase, 1, "送达后交替位翻转")
	_put(Vector2i(-1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 2), "第二次走 left 口")
	assert_eq(data.splitter_phase, 0)

func test_splitter_blocked_keeps_phase() -> void:
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_put(Vector2i(-1, 0), Item.num(1))
	_put(Vector2i(0, -1), Item.num(9))  # left 口被占
	data.splitter_phase = 1
	_tick(2)
	assert_true(_has_num(Vector2i(-1, 0), 1), "所选出口被占则等待")
	assert_eq(data.splitter_phase, 1, "未送达不翻转")

# ---------- 传送带+分流器一体建筑（分流器放在传送带上） ----------

func test_belt_splitter_alternates_from_own_cell() -> void:
	# 一体建筑 (1,0) E：读自身格物品，交替送前口 (2,0) / 左口 (1,-1)
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_put(Vector2i(1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "第一次应走前口（带子延续方向）")
	assert_eq(data.splitter_phase, 1, "送达后交替位翻转")
	_put(Vector2i(1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(1, -1), 2), "第二次应走左口")
	assert_eq(data.splitter_phase, 0)

func test_belt_splitter_blocked_keeps_phase() -> void:
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_put(Vector2i(1, 0), Item.num(1))
	_put(Vector2i(1, -1), Item.num(9))  # 左口被占（本周期输出位）
	data.splitter_phase = 1
	_tick(2)
	assert_true(_has_num(Vector2i(1, 0), 1), "所选出口被占则等待（物品停在自己格=带上）")
	assert_eq(data.splitter_phase, 1, "未送达不翻转")

func test_belt_splitter_accepts_item_from_upstream_belt() -> void:
	# 上游带 → 一体建筑格（不被 machine_cells 守卫拦截）→ 分流到前口带子续行
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(3, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "tick1: 上游带应把物品推进一体建筑格")
	_tick()
	assert_true(_has_num(Vector2i(3, 0), 1), "tick2: 分流器送到前口后带子应续行（(3,0) 末端）")
	assert_false(_grid.has_item(Vector2i(1, 0)), "一体建筑格应已清空")
	_tick()
	assert_true(_has_num(Vector2i(3, 0), 1), "tick3: 末端带子停滞（空地不接收）")

func test_belt_splitter_chain_flows_one_per_tick() -> void:
	# 带链带一体建筑的稳定吞吐：连续物品逐个进入并分流出去
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "物品1 进入一体建筑格")
	_put(Vector2i(0, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "物品1 被分流到前口格")
	assert_true(_has_num(Vector2i(1, 0), 2), "物品2 同时进入一体建筑格")

func test_belt_splitter_back_cell_not_docked() -> void:
	# 一体化建筑的后格（ins 视觉端口）不作为停靠格：上游带隔空一格时，
	# 物品应背压停在上游带上，而不是被推入后格永久卡死（无人消费）
	_buildings[Vector2i(-2, 0)] = _bd(MachineSpec.T_BELT)          # 上游带
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)  # 一体建筑（后格 (-1,0) 隔空）
	_put(Vector2i(-2, 0), Item.num(1))
	_tick(2)
	assert_true(_has_num(Vector2i(-2, 0), 1), "后格不是停靠格：物品应背压停在带子上")
	assert_false(_grid.has_item(Vector2i(-1, 0)), "后格不应接收物品（永久死停车位回归）")

# ---------- 筛选器 ----------

func test_filter_default_gt_zero() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_FILTER)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), ">0 走通过口")
	_put(Vector2i(-1, 0), Item.num(0))
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 0), "<=0 走拒绝口")

func test_filter_num_eq() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_FILTER, MachineSpec.DIR_E, {"filter_kind": "num", "filter_cmp": "eq", "filter_value": 5})
	_put(Vector2i(-1, 0), Item.num(5))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 5), "等于 5 通过")
	_put(Vector2i(-1, 0), Item.num(4))
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 4), "不等于 5 拒绝")

func test_filter_num_lt() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_FILTER, MachineSpec.DIR_E, {"filter_kind": "num", "filter_cmp": "lt", "filter_value": 0})
	_put(Vector2i(-1, 0), Item.num(-3))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), -3), "负数通过")
	_put(Vector2i(-1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 2), "非负数拒绝")

func test_filter_op_kind() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_FILTER, MachineSpec.DIR_E, {"filter_kind": "op", "filter_value": OpRegistry.OP_SUB1})
	_put(Vector2i(-1, 0), Item.op(OpRegistry.OP_SUB1))
	_tick()
	assert_true(_has_op(Vector2i(1, 0), OpRegistry.OP_SUB1), "选中操作通过")
	_put(Vector2i(-1, 0), Item.op(OpRegistry.OP_ADD1))
	_tick()
	assert_true(_has_op(Vector2i(0, -1), OpRegistry.OP_ADD1), "其他操作拒绝")

func test_filter_num_kind_rejects_op_item() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_FILTER)
	_put(Vector2i(-1, 0), Item.op(OpRegistry.OP_ADD1))
	_tick()
	assert_true(_has_op(Vector2i(0, -1), OpRegistry.OP_ADD1), "数字谓词下操作一律走拒绝口")

# ---------- 垃圾桶 ----------

func test_trash_removes_item() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_TRASH)
	_put(Vector2i(-1, 0), Item.num(1))
	var events := _tick()
	assert_true(_grid.is_empty(), "物品应被删除")
	assert_true(events.any(func(e: Dictionary) -> bool: return e.kind == "despawn"), "应有 despawn 事件")

# ---------- 非原点机器端口（回归：端口偏移曾直接当作世界坐标，机器不在原点时错位） ----------

func test_source_at_non_origin_produces_to_correct_world_pos() -> void:
	# 数字源 (5,5) E：出口应为 (6,5)，而不是偏移 (1,0) 直当世界
	_buildings[Vector2i(5, 5)] = _bd(MachineSpec.T_NUM_SOURCE)
	_tick()
	assert_true(_has_num(Vector2i(6, 5), 1), "非原点数字源的出口应落在机器格前方")
	assert_false(_grid.has_item(Vector2i(1, 0)), "偏移不应被当作世界坐标")

func test_source_at_non_origin_direction_south() -> void:
	# 数字源 (0,-3) S：出口应为 (0,-2)（前方=南），而不是错位到其他格
	_buildings[Vector2i(0, -3)] = _bd(MachineSpec.T_NUM_SOURCE, MachineSpec.DIR_S)
	_tick()
	assert_true(_has_num(Vector2i(0, -2), 1), "南向出口应落在机器格下方")
	assert_false(_grid.has_item(Vector2i(0, -1)), "左口等错位位置不应出现物品")

func test_applier_at_non_origin_uses_world_ports() -> void:
	# 应用器 (3,5) E：ins=(3,4)/(3,6)，out=(4,5)
	_buildings[Vector2i(3, 5)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(3, 4), Item.op(OpRegistry.OP_ADD1))
	_put(Vector2i(3, 6), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(4, 5), 2), "非原点应用器应在机器格前方输出")
	assert_false(_grid.has_item(Vector2i(0, -1)), "偏移不应被当作世界坐标（左口错位）")
	assert_false(_grid.has_item(Vector2i(0, 1)))

func test_splitter_at_non_origin_alternates_correctly() -> void:
	# 分流器 (2,2) E：in=(1,2)，outs front=(3,2) left=(2,1)
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(2, 2)] = data
	_put(Vector2i(1, 2), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(3, 2), 1), "第一次应走 front 口（机器格前方）")
	assert_eq(data.splitter_phase, 1)

# ---------- 机器格守卫（回归：机器阶段输出/落点必须是机器本体格） ----------

func test_source_output_blocked_by_machine_cell_waits() -> void:
	# 数字源 (0,0) S 的出口 (0,1) 恰好是应用器本体格：不得生成物品到机器格上（否则永久卡死）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE, MachineSpec.DIR_S)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_APPLIER)
	_tick(3)
	assert_false(_grid.has_item(Vector2i(0, 1)), "输出为机器本体格时物品不应生成到格上")
	assert_eq(_grid.count_items(), 0, "物品不应出现在任何格上")

func test_splitter_output_blocked_by_machine_cell_waits() -> void:
	# 分流器 (0,0) E 的 front 口 (1,0) 是应用器本体格：物品应背压停在输入格
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(-1, 0), 1), "输出为机器本体格时物品应背压等待在输入格")
	assert_false(_grid.has_item(Vector2i(1, 0)), "机器本体格不应出现物品")
	assert_eq(data.splitter_phase, 0, "未送达不翻转")

func test_applier_output_blocked_by_machine_cell_waits() -> void:
	# 应用器 (0,0) E 的输出 (1,0) 是数字源本体格：输入不被消耗（结果不会落到机器格上）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_put(Vector2i(0, -1), Item.op(OpRegistry.OP_ADD1))
	_put(Vector2i(0, 1), Item.num(1))
	_tick(3)
	assert_true(_has_op(Vector2i(0, -1), OpRegistry.OP_ADD1), "输出被占时输入不被消耗")
	assert_true(_has_num(Vector2i(0, 1), 1))
	assert_false(_grid.has_item(Vector2i(1, 0)), "机器本体格不应出现物品")

func test_filter_output_blocked_by_machine_cell_waits() -> void:
	# 筛选器 (0,0) E 的通过口 (1,0) 是分流器本体格：物品应背压停在输入格
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_FILTER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_SPLITTER)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(-1, 0), 1), "通过口为机器本体格时物品应背压等待在输入格")
	assert_false(_grid.has_item(Vector2i(1, 0)), "机器本体格不应出现物品")

func test_belt_splitter_output_blocked_by_machine_cell_waits() -> void:
	# 一体分流器 (1,0) E 的前口 (2,0) 是应用器本体格：物品应停在自己格（带上）等待
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(1, 0), 1), "前口为机器本体格时物品应停在自己格(带上)")
	assert_false(_grid.has_item(Vector2i(2, 0)), "机器本体格不应出现物品")
	assert_eq(data.splitter_phase, 0, "未送达不翻转")

# ---------- 综合 ----------

func test_feedback_counter_reaches_five_without_leak() -> void:
	# 计数回路（纯函数式迭代）：初始 1 → 应用器 +1 → 反馈带绕回右口，
	# 值每圈 +1。验证反馈带 = 迭代，且物品数量有界（背压不泄漏）。
	# 布局：
	#   应用器 (0,0) E：左口 (0,-1) 收 op，右口 (0,1) 收数据，出口 (1,0)
	#   操作物品由外部注入左口（操作源建筑已移除，模拟外部 op 供给）
	#   初始 1 放在带 (0,2) N → 右口 (0,1)
	#   反馈：出口 (1,0) E → (2,0) S → (2,1) W → (1,1) W → 右口 (0,1)
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER, MachineSpec.DIR_E)
	_buildings[Vector2i(0, 2)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(2, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_W)
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_W)
	_put(Vector2i(0, 2), Item.num(1))
	var events: Array[Dictionary] = []
	for i in range(30):
		events.append_array(ItemSimulator.tick(_buildings, _grid))
		# 左口空则补一个 +1（外部供给模拟，替代已移除的操作源）
		if not _grid.has_item(Vector2i(0, -1)):
			_put(Vector2i(0, -1), Item.op(OpRegistry.OP_ADD1))
	# 回路每 5-6 tick 迭代一次，30 tick 后值早已超过 5：
	# 在事件流中断言出现过 5（1→2→3→4→5 完整经过）
	var saw_five := false
	for e: Dictionary in events:
		if e.has("item"):
			var it: Item = e["item"]
			if it != null and it.is_num() and it.value == 5:
				saw_five = true
				break
	assert_true(saw_five, "反馈回路应把 1 迭代到 5（事件流中出现过值 5）")
	# 无泄漏：物品数量有界（背压不泄漏）
	assert_lt(_grid.count_items(), 10, "物品数量应有界（背压不泄漏）")