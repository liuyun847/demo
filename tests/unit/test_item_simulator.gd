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
	# 无方向源：四周无传送带/贴脸机器（空地不产）→ 背压等待，不产到空地
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_tick()
	_tick()
	assert_eq(_grid.count_items(), 0, "无接收方时源头不产出（不落空地）")

# ---------- 数字源无方向（自动向四周相邻传送带/贴脸机器输出） ----------

func test_num_source_feeds_adjacent_belt_any_direction() -> void:
	# 源 (0,0) 北邻带 (0,-1)：无方向自动喂北向带（不再需要旋转对准输出口）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 1), "源应自动产出到北侧相邻带格")

func test_num_source_output_priority_n_e_s_w() -> void:
	# 四周都有带：按北→东→南→西优先级，北带先收到
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	for off: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		_buildings[Vector2i(0, 0) + off] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(0, -1), 1), "北向带应优先收到（北→东→南→西）")
	assert_false(_grid.has_item(Vector2i(1, 0)), "北带可投时东带不收到")
	assert_false(_grid.has_item(Vector2i(0, 1)))
	assert_false(_grid.has_item(Vector2i(-1, 0)))

func test_num_source_skips_blocked_direction() -> void:
	# 北带被占 → 换东带输出；北带原物品不动（不覆盖）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, -1), Item.num(9))  # 北带被占
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "北带被占时应换到东带输出")
	assert_true(_has_num(Vector2i(0, -1), 9), "北带原物品不应被覆盖")
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "东带被占（物品未移走）时源等待，不再产出")

func test_num_source_feeds_belt_splitter_cell() -> void:
	# 源东邻一体建筑格（带子语义）：产出落到其格，同相位被分流
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "源产出应落到一体建筑格并被分流到前口带子")

func test_num_source_ignores_misaligned_machine() -> void:
	# 源东邻应用器但输入口在两侧（不对齐）→ 无方向源不产（不写面槽、不落机器格）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_APPLIER)
	_tick(3)
	assert_eq(_grid.count_items(), 0, "不对齐机器不算接收方，源不产出")
	assert_eq(_grid.count_edge_items(), 0, "不对齐不写入面槽")

func test_num_source_any_receiver_allows_production() -> void:
	# 四周任意一个带子即可产出（无需指定方向/旋转）；西带同样工作
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(-1, 0), 1), "源应自动产出到西侧相邻带格")

# ---------- 应用器（输入口角色固定：数据口=ins[0]=(0,-1)，操作口=ins[1]=(0,1)） ----------

func test_applier_computes_op_on_num() -> void:
	# 数据口 num(1) + 操作口 op(+1) → 2
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(1))
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_ADD1))
	var events := _tick()
	assert_true(_has_num(Vector2i(1, 0), 2), "1 + 1 = 2")
	assert_false(_grid.has_item(Vector2i(0, -1)), "输入应被消耗")
	assert_false(_grid.has_item(Vector2i(0, 1)))
	var despawn_count := 0
	for e: Dictionary in events:
		if e.kind == "despawn":
			despawn_count += 1
	assert_eq(despawn_count, 2)

func test_applier_op_port_number_adds() -> void:
	# 操作口放数字 n = "+n"（操作物品暂缺生产来源，数字即操作）：3 + 2 = 5
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(3))
	_put(Vector2i(0, 1), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 5), "3 + 2 = 5（数字 n = +n）")
	assert_false(_grid.has_item(Vector2i(0, -1)), "两输入应被消耗")
	assert_false(_grid.has_item(Vector2i(0, 1)))

func test_applier_two_numbers_add() -> void:
	# 存档场景语义：两路数字源各产 1 → 1 + 1 = 2
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(1))
	_put(Vector2i(0, 1), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 2), "1 + 1 = 2（操作口数字 1 = +1）")

func test_applier_data_port_op_waits() -> void:
	# 数据口只收数字：操作物品放数据口 → 类型不匹配，等待不消耗
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.op(OpRegistry.OP_ADD1))
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_MUL2))
	_tick(2)
	assert_true(_has_op(Vector2i(0, -1), OpRegistry.OP_ADD1), "数据口 op 应等待")
	assert_true(_has_op(Vector2i(0, 1), OpRegistry.OP_MUL2))

func test_applier_waits_for_second_input() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(1))
	_tick(2)
	assert_true(_has_num(Vector2i(0, -1), 1), "输入未到齐应积压等待")

func test_applier_output_blocked_waits() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, -1), Item.num(1))
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_ADD1))
	_put(Vector2i(1, 0), Item.num(9))
	_tick(2)
	assert_true(_has_num(Vector2i(0, -1), 1), "输出被占时输入不被消耗")
	assert_true(_has_op(Vector2i(0, 1), OpRegistry.OP_ADD1))

func test_applier_save_scene_flow() -> void:
	# 存档场景：两路数字源各经 6 格带（末格 (6,±1) 为应用器端口带，顺带抽取）喂应用器
	# 上(数据)/下(操作)口 → 输出 2 进入下游带子
	# 数字源 (0,-1)/(0,1) → 带 (1..6,±1) E → 应用器 (6,0) E → 带 (7,0)/(8,0)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_NUM_SOURCE)
	for i in range(1, 7):
		_buildings[Vector2i(i, -1)] = _bd(MachineSpec.T_BELT)
		_buildings[Vector2i(i, 1)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(6, 0)] = _bd(MachineSpec.T_APPLIER)
	_buildings[Vector2i(7, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(8, 0)] = _bd(MachineSpec.T_BELT)
	for i in range(30):
		_tick()
		if _has_num(Vector2i(8, 0), 2):
			break
	assert_true(_has_num(Vector2i(8, 0), 2), "1 + 1 = 2 应流到下游带子（存档场景）")

# ---------- 分流器（四向：任意口进出、均分轮询、不阻塞） ----------

func test_splitter_round_robin_two_outputs() -> void:
	# 西入 + 东/南两条输出带（各 2 格，末端可积压）：均分轮询（1→东、2→南、3→东、4→南）
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(0, 2)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	for i in range(1, 5):
		_put(Vector2i(-1, 0), Item.num(i))
		_tick()
		assert_false(_grid.has_item(Vector2i(-1, 0)), "第 %d 个物品应被取走" % i)
	assert_true(_has_num(Vector2i(2, 0), 1) or _has_num(Vector2i(1, 0), 3), "1、3 走东口（轮询）")
	assert_true(_has_num(Vector2i(0, 2), 2) or _has_num(Vector2i(0, 1), 4), "2、4 走南口（轮询）")

func test_splitter_skips_blocked_output_non_blocking() -> void:
	# 东口被占 → 自动换南口（不阻塞）。输入轮询起始方向设为西（防东口阻塞物被优先读为输入）
	var data := _bd(MachineSpec.T_SPLITTER)
	data.splitter_in_phase = MachineSpec.DIR_W
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_put(Vector2i(1, 0), Item.num(9))   # 东口被占
	_put(Vector2i(-1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(0, 1), 1), "东口被占时应改走南口（不阻塞）")
	assert_eq(data.splitter_phase, MachineSpec.DIR_W, "投递后输出相位推进到下一方向（西）")
	_put(Vector2i(-1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 2), "东口空出后轮询到东口投递")

func test_splitter_all_outputs_blocked_waits() -> void:
	# 全部输出被占 → 背压等待（不读输入、物品不丢）
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(0, 2)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_put(Vector2i(1, 0), Item.num(9))
	_put(Vector2i(2, 0), Item.num(9))
	_put(Vector2i(0, 1), Item.num(9))
	_put(Vector2i(0, 2), Item.num(9))
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(-1, 0), 1), "输出全被占应等待在输入格")
	assert_eq(data.splitter_phase, 0, "未投递不动相位")

func test_splitter_no_receiver_waits_no_drop() -> void:
	# 周围无承接方（空地）→ 物品不落空地，等待
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(-1, 0), 1), "无承接方应等待（不落空地）")
	assert_eq(data.splitter_phase, 0)

func test_splitter_does_not_output_back_to_input() -> void:
	# 输出排除输入方向：单入口单出口时不会把物品投回输入格
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "应投到唯一承接方向（东）")
	assert_false(_grid.has_item(Vector2i(-1, 0)), "输入格应被清空（未投回）")

func test_splitter_input_round_robin_alternates() -> void:
	# 双输入链（西+北）：轮询交替读取（不饿死单链）
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(1))
	_put(Vector2i(0, -1), Item.num(2))
	_tick()
	assert_false(_grid.has_item(Vector2i(-1, 0)), "第一次应读西口")
	_tick()
	assert_false(_grid.has_item(Vector2i(0, -1)), "第二次应读北口")
	# 两物品最终都到东口带子
	_tick(3)
	assert_true(_has_num(Vector2i(2, 0), 1) or _has_num(Vector2i(1, 0), 2), "东口带应收到分流物品")

## 回归：默认初始相位（phase=0, in_phase=0）时北向输入必须可读——
## last_out 跳过逻辑曾把 (0-1+4)%4=北 当作"上一轮输出方向"跳过；北是扫描（东→南→
## 西→北）的最后一项，扫到即被跳过 → 北口物品永久死锁、相位永不推进
func test_splitter_north_input_readable_at_initial_phase() -> void:
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, -1), Item.num(7))  # 北口输入（默认扫描顺序东→南→西→北，北是最后一项）
	_tick()
	assert_false(_grid.has_item(Vector2i(0, -1)), "北口物品应被读取（不因 last_out 死锁）")
	assert_true(_has_num(Vector2i(1, 0), 7) or _has_num(Vector2i(2, 0), 7), "北口输入应被投递到东口带子")

## 回归（一体建筑自身格投递回绕）：自身格投北后 phase 回绕 0 且 in_phase 保持 0
## （自身格读取不推进输入相位），若用相位反推 last_out 会误判"从未投递"；断供后
## 外部轮询必须仍跳过北口（刚投出方向），否则积压物被读回 → 端口格间循环搬运
func test_belt_splitter_own_cell_delivery_north_skips_last_out() -> void:
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	# 仅北口承接带（东/南/西为空地不承接）→ 自身格物品唯一可投北口
	_buildings[Vector2i(1, -1)] = _bd(MachineSpec.T_BELT)
	# 自身格物品投北（phase = (3+1)%4 = 0，回绕；自身格读取不推进 in_phase → 仍 0）
	_put(Vector2i(1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, -1), 1), "自身格物品应投北口")
	assert_eq(data.splitter_phase, 0, "投北后 phase 回绕到 0")
	assert_eq(data.splitter_in_phase, 0, "自身格读取不推进输入相位")
	assert_eq(data.last_out_dir, MachineSpec.DIR_N, "last_out_dir 应记录北")
	# 断供：自身格空；北口承接带积压（刚投出的物品停在下游带子末端）
	# 北口端口格 (1,-1) 上的物品应不被外部轮询读回（last_out=北 跳过）
	_put(Vector2i(1, -1), Item.num(1))  # 积压物品停在北口带子
	_tick(2)
	assert_true(_has_num(Vector2i(1, -1), 1), "北口积压物品不被读回（防循环搬运）")

## 回归（一体建筑）：默认初始相位下北向端口物品同样可读（同一 _find_input 路径）
func test_belt_splitter_north_port_input_readable_at_initial_phase() -> void:
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(1, -1), Item.num(5))  # 北口端口（自身格为空，轮询外部端口）
	_tick()
	assert_false(_grid.has_item(Vector2i(1, -1)), "一体建筑北口物品应被读取")
	assert_true(_has_num(Vector2i(2, 0), 5), "北口输入应被投递到东口带子")

## 回归：投递后 last_out 跳过仍生效（防端口格间循环搬运）——物品投出后若停在
## 输出端口格（下游积压），输入轮询不得读回该方向（否则物品在端口格间循环搬运）；
## 其他方向的输入应正常读取
func test_splitter_does_not_read_back_last_output_after_delivery() -> void:
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	# 第 1 个物品：西入 → 投东（投递后带子推进到 (2,0)，相位推进到南）
	_put(Vector2i(-1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1) or _has_num(Vector2i(1, 0), 1), "第一个物品投东口")
	assert_eq(data.splitter_phase, MachineSpec.DIR_S, "投递后输出相位推进到南")
	assert_eq(data.last_out_dir, MachineSpec.DIR_E, "普通分流器投递后 last_out_dir 应记录东（_fire_splitter 路径）")
	# 模拟下游积压：东口端口格 (1,0) 停物品（投递过的方向=东，last_out=东）
	_put(Vector2i(1, 0), Item.num(9))
	# 北口放输入：last_out=东 已从输入轮询排除，北口物品应被读取
	_put(Vector2i(0, -1), Item.num(2))
	_tick()
	assert_false(_grid.has_item(Vector2i(0, -1)), "北口物品应被读取（东口被 last_out 排除）")
	assert_true(_has_num(Vector2i(1, 0), 9), "东口积压物品不被读回（防循环搬运）")

# ---------- 传送带+分流器一体建筑（分流器放在传送带上） ----------

func test_belt_splitter_round_robin_from_own_cell() -> void:
	# 一体建筑 (1,0)：读自身格物品，4 向轮询输出（东+南带）
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_put(Vector2i(1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "第一次走东口")
	assert_eq(data.splitter_phase, MachineSpec.DIR_S, "投递后相位推进到南")
	_put(Vector2i(1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(1, 1), 2), "第二次走南口")
	assert_eq(data.splitter_phase, MachineSpec.DIR_W)

func test_belt_splitter_blocked_switches_output() -> void:
	# 东口被占 → 自动换南口（不阻塞）
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 1)] = _bd(MachineSpec.T_BELT)  # (2,1) 承接南口（物品 9 停 (2,0) 不影响）
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_put(Vector2i(2, 0), Item.num(9))  # 东口带被占
	_put(Vector2i(1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 1), 1), "东口被占时应改走南口（不阻塞）")

func test_belt_splitter_all_outputs_blocked_keeps_item() -> void:
	# 全部输出被占 → 物品停在自己格（带上）等待
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(1, 2)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_put(Vector2i(2, 0), Item.num(9))
	_put(Vector2i(1, 1), Item.num(9))
	_put(Vector2i(1, 2), Item.num(9))
	_put(Vector2i(1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(1, 0), 1), "输出全被占物品应停在自己格(带上)")
	assert_eq(data.splitter_phase, 0, "未投递不动相位")

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

func test_belt_splitter_no_upstream_recycle() -> void:
	# 一体建筑不投回上游方向（防回流循环）：上游带迎向本格，输出应避开该方向
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)  # 上游带朝东（迎向一体建筑）
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 1)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1) or _has_num(Vector2i(1, 1), 1), "输出应走东/南（非上游西）")
	assert_false(_grid.has_item(Vector2i(0, 0)), "不应投回上游带格")

func test_belt_splitter_back_cell_not_docked() -> void:
	# 一体化建筑端口格不加入停靠（原"后格不接收"回归）：上游带隔空一格时，
	# 物品应背压停在上游带上，而不是被推入后格永久卡死（一体建筑输入排除上游方向，
	# 物品应沿带自然流入自身格）
	_buildings[Vector2i(-2, 0)] = _bd(MachineSpec.T_BELT)          # 上游带
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)  # 一体建筑（后格 (-1,0) 隔空）
	_put(Vector2i(-2, 0), Item.num(1))
	_tick(2)
	assert_true(_has_num(Vector2i(-2, 0), 1), "物品应背压停在带子上（后格不接收）")
	assert_false(_grid.has_item(Vector2i(-1, 0)), "后格不应接收物品（永久死停车位回归）")

# ---------- 分流器按方向过滤（原筛选器能力并入） ----------

func test_splitter_filter_matched_dir_routes() -> void:
	# 东向设 eq 5、其余无条件：5 从西入 → 走匹配的东口
	var data := _bd(MachineSpec.T_SPLITTER)
	data.splitter_filters[MachineSpec.DIR_E] = {"kind": "num", "cmp": "eq", "value": 5}
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(5))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 5), "匹配物品应走东口（首个匹配+承接方向）")

func test_splitter_filter_mismatch_dir_skipped_to_next() -> void:
	# 东向 eq 5、南无条件：3 在相位=东时东口不匹配 → 跳过走南（不阻塞，不销毁）
	var data := _bd(MachineSpec.T_SPLITTER)
	data.splitter_filters[MachineSpec.DIR_E] = {"kind": "num", "cmp": "eq", "value": 5}
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(5))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 5), "5 走匹配的东口")
	_put(Vector2i(-1, 0), Item.num(3))
	_tick()
	assert_true(_has_num(Vector2i(0, 1), 3), "3 东口不匹配 → 跳到无条件南口")

func test_splitter_filter_all_dirs_mismatch_backpressure() -> void:
	# 四方向全设条件且均不匹配 → 物品滞留输入格背压，两相位均不推进（物品不丢）
	var data := _bd(MachineSpec.T_SPLITTER)
	data.splitter_filters = [
		{"kind": "num", "cmp": "gt", "value": 100},
		{"kind": "num", "cmp": "gt", "value": 100},
		{"kind": "num", "cmp": "gt", "value": 100},
		{"kind": "num", "cmp": "lt", "value": -100},
	]
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(-1, 0), 1), "全部方向不匹配 → 物品滞留输入格背压")
	assert_eq(data.splitter_phase, 0, "未投递输出相位不动")
	assert_eq(data.splitter_in_phase, 0, "未投递输入相位不动")

func test_splitter_filter_matched_dir_occupied_switches() -> void:
	# 东向与南向条件均匹配，但东口被未对齐机器本体格堵死（machine_cells 守卫 =
	# 输出被占，且该格不是可读输入口）→ 换到下一个同样匹配的南口（条件与被占叠加换向）
	var data := _bd(MachineSpec.T_SPLITTER)
	data.splitter_filters[MachineSpec.DIR_E] = {"kind": "num", "cmp": "gt", "value": 0}
	data.splitter_filters[MachineSpec.DIR_S] = {"kind": "num", "cmp": "gt", "value": 0}
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_APPLIER, MachineSpec.DIR_E)  # 东侧机器：输入口在南北两侧，未正对分流器（不对齐=输出被占）
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)     # 南口带（朝北，物品投上后停在带上）
	_buildings[Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT)                       # 西侧输入带
	_put(Vector2i(-1, 0), Item.num(2))
	_tick()
	assert_true(_has_num(Vector2i(0, 1), 2), "东被占 → 跳到同样匹配的南口")

func test_splitter_filter_op_condition() -> void:
	# 西向设操作条件：匹配的操作物品走西口，数字不匹配该方向走其他无条件口
	var data := _bd(MachineSpec.T_SPLITTER)
	data.splitter_phase = MachineSpec.DIR_W  # 从西口开始轮询
	data.splitter_filters[MachineSpec.DIR_W] = {"kind": "op", "value": OpRegistry.OP_SUB1}
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT)  # 西口承接带
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT)   # 南口承接带
	_put(Vector2i(1, 0), Item.op(OpRegistry.OP_SUB1))
	_tick()
	assert_true(_has_op(Vector2i(-1, 0), OpRegistry.OP_SUB1), "匹配操作物品走西口")
	_put(Vector2i(1, 0), Item.num(4))
	_tick()
	assert_true(_has_num(Vector2i(0, 1), 4), "数字在西口不匹配 → 走无条件南口")

func test_splitter_no_filters_behaves_unchanged() -> void:
	# 回归：全无条件（默认）时轮询分流行为与旧版一致
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 1), "全无条件走东口（默认相位）")
	assert_eq(data.splitter_phase, MachineSpec.DIR_S, "投递后相位推进")

func test_belt_splitter_filter_gates_own_cell_item() -> void:
	# 一体建筑自身格流入 + 东口条件不匹配（唯一承接方向）→ 物品滞留自身格背压
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	data.splitter_filters[MachineSpec.DIR_E] = {"kind": "num", "cmp": "eq", "value": 5}
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)   # 东口承接带（唯一承接方向）
	_buildings[Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT)  # 上游带流入自身格
	_put(Vector2i(-1, 0), Item.num(3))
	_tick(2)
	assert_true(_has_num(Vector2i(0, 0), 3), "东口条件不匹配 → 物品滞留自身格背压")
	assert_false(_grid.has_item(Vector2i(1, 0)), "不应投到东口")

func test_belt_splitter_filter_matched_own_cell_item_flows() -> void:
	# 一体建筑自身格物品匹配东口条件 → 正常投到东口带
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	data.splitter_filters[MachineSpec.DIR_E] = {"kind": "num", "cmp": "eq", "value": 5}
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(5))
	_tick(2)
	assert_true(_has_num(Vector2i(1, 0), 5), "匹配物品应投到东口带")

# ---------- 垃圾桶（接受传送带输入 + 贴脸投递；不从旁格吸取） ----------

func test_trash_accepts_belt_delivery() -> void:
	# 传送带输入：带子把物品推进垃圾桶本体格（本体格可停靠、不进 machine_cells
	# 守卫）→ 垃圾桶在机器阶段销毁自身格物品
	var trash := Vector2i(3, 3)
	_buildings[trash] = _bd(MachineSpec.T_TRASH)
	_buildings[trash + Vector2i(-1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_put(trash + Vector2i(-1, 0), Item.num(9))
	_tick(3)
	assert_false(_grid.has_item(trash + Vector2i(-1, 0)), "带格物品应已推进垃圾桶本体格")
	assert_false(_grid.has_item(trash), "垃圾桶本体格物品应已被销毁")
	assert_eq(_grid.count_items(), 0, "物品应全部销毁，不留存")

func test_trash_belt_delivery_backpressure() -> void:
	# 传送带链尾接垃圾桶：物品逐 tick 流入并销毁，不积压（排泄口语义）
	var trash := Vector2i(5, 0)
	_buildings[trash] = _bd(MachineSpec.T_TRASH)
	for x in range(4, -1, -1):
		_buildings[Vector2i(x, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_put(Vector2i(0, 0), Item.num(1))
	_put(Vector2i(1, 0), Item.num(2))
	_put(Vector2i(2, 0), Item.num(3))
	_tick(8)
	assert_eq(_grid.count_items(), 0, "全部物品应流入垃圾桶并销毁")
	assert_true(_grid.is_empty(), "网格应清空")

func test_trash_ignores_grid_item() -> void:
	# 垃圾桶不从旁格主动吸取：物品在旁格带格上，但带子不指向垃圾桶（南向带）→
	# 物品不会被销毁、不被吸入
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_TRASH)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_put(Vector2i(1, 0), Item.num(1))
	var events := _tick(3)
	assert_true(_has_num(Vector2i(1, 0), 1), "旁格网格物品不应被销毁（带子不指向垃圾桶）")
	assert_false(events.any(func(e: Dictionary) -> bool: return e.kind == "despawn"), "不应有 despawn 事件")

func test_trash_ignores_belt_adjacent_item() -> void:
	# 带子指向垃圾桶：西端口格 (2,3) 不在可停靠集合（垃圾桶端口格不可停靠）→
	# 移动阶段守卫阻止带子把物品推进端口格，物品留在带格上，不被销毁
	var trash := Vector2i(3, 3)
	_buildings[trash] = _bd(MachineSpec.T_TRASH)
	_buildings[trash + Vector2i(-2, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_put(trash + Vector2i(-2, 0), Item.num(9))
	_tick(3)
	assert_true(_has_num(trash + Vector2i(-2, 0), 9), "物品应留在带格，不被销毁")
	assert_false(_grid.has_item(trash + Vector2i(-1, 0)), "物品不应进入垃圾桶西端口格（不可停靠）")
	assert_false(_grid.has_item(trash), "垃圾桶本体格不应出现物品")
	assert_eq(_grid.count_edge_items(), 0, "不应产生面槽物品")

func test_trash_accepts_face_delivery_from_applier() -> void:
	# 应用器输出口正对垃圾桶：计算结果经面槽投递被销毁
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_TRASH)
	_put(Vector2i(0, -1), Item.num(1))
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_ADD1))
	var events := _tick()
	assert_true(_grid.is_empty(), "应用器投递的物品应被垃圾桶销毁")
	assert_eq(_grid.count_edge_items(), 0, "面槽应被垃圾桶消费清空")
	assert_true(events.any(func(e: Dictionary) -> bool: return e.kind == "despawn"), "应有 despawn 事件")

func test_trash_face_delivery_on_belt_splitter_cell() -> void:
	# 回归：垃圾桶旁格是一体建筑（传送带+分流器），该格可同时持有网格物品与
	# 面槽投递物。垃圾桶必须只销毁面槽投递物，不得误取网格物品
	# （曾因 _take_input 网格优先导致误销毁网格物品+面槽永久滞留）。
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_TRASH)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_put(Vector2i(1, 0), Item.num(5))  # 一体建筑格上的网格物品
	_grid.set_edge(Vector2i(1, 0), Item.num(7), Vector2i(1, 0))  # 一体建筑向东（垃圾桶）投递的面槽物品
	var events := _tick()
	# 单 tick 内：面槽 (7) 被销毁（despawn 事件），网格 (5) 仍在（未被误取）
	var despawned: Array[Dictionary] = events.filter(func(e: Dictionary) -> bool: return e.kind == "despawn")
	assert_eq(despawned.size(), 1, "本 tick 应恰好销毁 1 个（面槽投递物）")
	assert_eq(_grid.count_edge_items(), 0, "面槽投递物品应被垃圾桶消费清空")
	assert_true(_has_num(Vector2i(1, 0), 5), "一体建筑格上的网格物品不应被垃圾桶误销毁")
	if despawned.size() == 1:
		var it: Item = despawned[0].get("item") as Item
		assert_true(it != null and it.is_num() and it.value == 7, "销毁的应是面槽投递物 (7)，而非网格物品 (5)")

func test_trash_own_cell_priority_over_face() -> void:
	# 优先级：垃圾桶本体格物品优先于面槽投递物——同 tick 只销毁本格物品，
	# 面槽物品滞留到下一 tick（每 tick 至多 1 个）
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_TRASH)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_put(Vector2i(2, 0), Item.num(5))  # 垃圾桶本体格物品（带子推入后待销毁）
	_grid.set_edge(Vector2i(1, 0), Item.num(7), Vector2i(1, 0))  # 一体建筑向东投递的面槽物品
	var events := _tick()
	var despawned: Array[Dictionary] = events.filter(func(e: Dictionary) -> bool: return e.kind == "despawn")
	assert_eq(despawned.size(), 1, "本 tick 只销毁 1 个（本格物品优先）")
	assert_false(_grid.has_item(Vector2i(2, 0)), "本格物品应已被销毁")
	assert_eq(_grid.count_edge_items(), 1, "面槽投递物应滞留到下一 tick")
	if despawned.size() == 1:
		var it: Item = despawned[0].get("item") as Item
		assert_true(it != null and it.is_num() and it.value == 5, "销毁的应是本格物品 (5)")
	# 下一 tick 面槽被消费
	_tick()
	assert_eq(_grid.count_edge_items(), 0, "第 2 tick 面槽投递物被销毁")

func test_trash_one_item_per_tick() -> void:
	# 每 tick 至多消费 1 个（与其他机器节奏一致）：两个一次性投递源（应用器），
	# 第 1 tick 只删 1 个，第 2 tick 删剩下 1 个
	var trash := Vector2i(2, 2)
	_buildings[trash] = _bd(MachineSpec.T_TRASH)
	# 北侧与东侧各一个应用器（输出口分别正对垃圾桶北/东口；输入一次性放置）
	var applier_n := Vector2i(2, 1)
	_buildings[applier_n] = _bd(MachineSpec.T_APPLIER, MachineSpec.DIR_S)
	# 面向南：数据口(ins[0])旋转后在东 (1,0)，操作口(ins[1])在西 (-1,0)，输出在南 (0,1)
	_put(applier_n + Vector2i(1, 0), Item.num(1))
	_put(applier_n + Vector2i(-1, 0), Item.op(OpRegistry.OP_ADD1))
	var applier_e := Vector2i(3, 2)
	_buildings[applier_e] = _bd(MachineSpec.T_APPLIER, MachineSpec.DIR_W)
	# 面向西：数据口(ins[0])旋转后在南 (0,1)，操作口(ins[1])在北 (0,-1)，输出在西 (-1,0)
	_put(applier_e + Vector2i(0, 1), Item.num(1))
	_put(applier_e + Vector2i(0, -1), Item.op(OpRegistry.OP_ADD1))
	_tick()
	assert_eq(_grid.count_edge_items(), 1, "每 tick 至多消费 1 个：另一源的面槽物品滞留")
	_tick()
	assert_eq(_grid.count_edge_items(), 0, "第 2 tick 消费剩余物品")

# ---------- 非原点机器端口（回归：端口偏移曾直接当作世界坐标，机器不在原点时错位） ----------

func test_source_at_non_origin_produces_to_correct_world_pos() -> void:
	# 数字源 (5,5) 无方向：东邻带 (6,5) 承接，产出应落在 (6,5)（相邻带格），
	# 而不是偏移 (1,0) 直当世界坐标
	_buildings[Vector2i(5, 5)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(6, 5)] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(6, 5), 1), "非原点数字源应产出到相邻带格")
	assert_false(_grid.has_item(Vector2i(1, 0)), "偏移不应被当作世界坐标")

func test_source_at_non_origin_direction_south() -> void:
	# 数字源 (0,-3) 无方向：南邻带 (0,-2) 承接，产出应落在 (0,-2)，而不是错位到其他格
	_buildings[Vector2i(0, -3)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(0, -2)] = _bd(MachineSpec.T_BELT)
	_tick()
	assert_true(_has_num(Vector2i(0, -2), 1), "产出应落在南侧相邻带格")
	assert_false(_grid.has_item(Vector2i(0, -1)), "错位位置不应出现物品")

func test_applier_at_non_origin_uses_world_ports() -> void:
	# 应用器 (3,5) E：ins[0]=(3,4) 数据口、ins[1]=(3,6) 操作口，out=(4,5)
	_buildings[Vector2i(3, 5)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(3, 4), Item.num(1))
	_put(Vector2i(3, 6), Item.op(OpRegistry.OP_ADD1))
	_tick()
	assert_true(_has_num(Vector2i(4, 5), 2), "非原点应用器应在机器格前方输出")
	assert_false(_grid.has_item(Vector2i(0, -1)), "偏移不应被当作世界坐标（左口错位）")
	assert_false(_grid.has_item(Vector2i(0, 1)))

func test_splitter_at_non_origin_alternates_correctly() -> void:
	# 分流器 (2,2)：西入，东口承接带，物品投递后输出相位推进
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(2, 2)] = data
	_buildings[Vector2i(3, 2)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(1, 2), Item.num(1))
	_tick()
	assert_true(_has_num(Vector2i(3, 2), 1), "物品应投到东口承接带（机器格前方）")
	assert_eq(data.splitter_phase, MachineSpec.DIR_S, "投递后输出相位推进到南")

# ---------- 机器格守卫（回归：机器阶段输出/落点必须是机器本体格） ----------

func test_source_output_blocked_by_machine_cell_waits() -> void:
	# 数字源 (0,0) S 的出口 (0,1) 恰好是应用器本体格：物品不得生成到机器格上（否则永久卡死）。
	# 应用器北侧输入口 == 源本体格（口对口贴合）→ 改走面槽直传：物品压在共享边上等消费；
	# 机器本体格仍永不持有网格物品（本守卫回归语义不变）。
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE, MachineSpec.DIR_S)
	_buildings[Vector2i(0, 1)] = _bd(MachineSpec.T_APPLIER)
	_tick(3)
	assert_false(_grid.has_item(Vector2i(0, 1)), "输出为机器本体格时物品不应生成到格上")
	assert_eq(_grid.count_items(), 0, "物品不应出现在任何网格格上")
	assert_eq(_grid.count_edge_items(), 1, "贴合直传: 物品应压在与应用器北口对齐的面槽上等待")

func test_splitter_output_blocked_by_machine_cell_waits() -> void:
	# 分流器 (0,0) 东侧是应用器本体格（不对齐无面槽承接），其余方向空地无承接：
	# 全部不可投 → 物品背压停在输入格（机器本体格守卫 + 不落空地）
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(-1, 0), 1), "无可投方向时物品应背压等待在输入格")
	assert_false(_grid.has_item(Vector2i(1, 0)), "机器本体格不应出现物品")
	assert_eq(data.splitter_phase, 0, "未送达不翻转")

func test_applier_output_blocked_by_machine_cell_waits() -> void:
	# 应用器 (0,0) E 的输出 (1,0) 是数字源本体格：输入不被消耗（结果不会落到机器格上）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_put(Vector2i(0, -1), Item.num(1))
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_ADD1))
	_tick(3)
	assert_true(_has_num(Vector2i(0, -1), 1), "输出被占时输入不被消耗")
	assert_true(_has_op(Vector2i(0, 1), OpRegistry.OP_ADD1))
	assert_false(_grid.has_item(Vector2i(1, 0)), "机器本体格不应出现物品")

func test_splitter_output_to_machine_cell_feeds_via_face() -> void:
	# 分流器 (0,0) 的东口 (1,0) 是分流器本体格；对方输入口正对本格（互认贴合）
	# → 物品经面槽直传喂入，0 格串链流动
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = data
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(1))
	_tick(3)
	assert_false(_grid.has_item(Vector2i(1, 0)), "机器本体格不应出现物品")
	assert_true(_has_num(Vector2i(2, 0), 1), "贴脸直传后物品应到达分流器前口带子")
	assert_eq(_grid.count_edge_items(), 0, "面槽应被分流器消费清空")

func test_face_splitter_to_splitter_chain_flows() -> void:
	# 需求: 0 格贴脸串链（存档第三行同类布局）——分流器东口直传分流器输入
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_SPLITTER)
	var splitter_data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(1, 0)] = splitter_data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(5))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 5), "筛选器→分流器 0 格串链应流动到前口带子")
	assert_false(_grid.has_item(Vector2i(-1, 0)), "筛选器输入应被取走")
	assert_eq(splitter_data.splitter_phase, MachineSpec.DIR_S, "投递后分流器输出相位推进到南")

func test_belt_splitter_output_blocked_by_machine_cell_waits() -> void:
	# 一体分流器 (1,0) 东侧是应用器本体格（不对齐无面槽承接），其余方向空地：
	# 全部不可投 → 物品应停在自己格（带上）等待
	var data := _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = data
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(1, 0), Item.num(1))
	_tick(3)
	assert_true(_has_num(Vector2i(1, 0), 1), "无可投方向时物品应停在自己格(带上)")
	assert_false(_grid.has_item(Vector2i(2, 0)), "机器本体格不应出现物品")
	assert_eq(data.splitter_phase, 0, "未送达不翻转")

# ---------- 0 格贴脸直传（机器口对口，面槽 edge_slots） ----------

func test_face_source_feeds_adjacent_splitter() -> void:
	# 存档第三行头部布局: 数字源(0,-6) 紧贴 分流器(1,-6)，双口对齐 → 经面槽直传
	_buildings[Vector2i(0, -6)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, -6)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(2, -6)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(3, -6)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, -7)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)
	_tick()
	assert_true(_has_num(Vector2i(3, -6), 1), "tick1: 贴脸直传→前口带子推进到末端")
	assert_eq(_grid.count_edge_items(), 0, "面槽应被分流器同相位消费")
	_tick()
	assert_true(_has_num(Vector2i(1, -7), 1), "tick2: 第二次走左口（北向带）")
	assert_true(_has_num(Vector2i(3, -6), 1), "前口物品不受影响")
	assert_false(_grid.has_item(Vector2i(1, -6)), "分流器本体格不应出现物品")

func test_face_backpressure_edge_holds_one() -> void:
	# 分流器四周无承接带（splitter_phase 起点=南）→ 面槽只允许 1 个物品，源背压停止产出
	var data := _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = data
	_put(Vector2i(1, -1), Item.num(9))  # 北口有物品但空地不承接
	data.splitter_phase = 1
	_tick(5)
	assert_eq(_grid.count_edge_items(), 1, "面槽应恰好持有 1 个等待物品")
	assert_eq(_grid.count_items(), 1, "不产生额外物品（背压）")
	assert_eq(data.splitter_phase, 1, "未送达不翻转")

func test_face_source_feeds_adjacent_trash() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_TRASH)
	for i in range(5):
		_tick()
	assert_true(_grid.is_empty(), "贴脸垃圾桶应持续消费源产物品")
	assert_eq(_grid.count_edge_items(), 0, "面槽应被垃圾桶即刻消费")

func test_face_applier_mixed_grid_and_face_inputs() -> void:
	# 应用器北侧输入 = 数字源贴脸直传；南侧输入 = 手动放置 op → 同相位计算
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_NUM_SOURCE, MachineSpec.DIR_S)
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER)
	_put(Vector2i(0, 1), Item.op(OpRegistry.OP_ADD1))
	_tick()
	assert_true(_has_num(Vector2i(1, 0), 2), "1 + 1 = 2（面输入与网格输入混合）")
	assert_false(_grid.has_item(Vector2i(0, 1)), "南侧 op 应被消耗")
	assert_eq(_grid.count_edge_items(), 0, "面输入应被消耗")

func test_face_wrong_orientation_never_writes_edge() -> void:
	# 数字源(0,0) E 输出口 == 应用器(1,0) 本体格，但应用器输入口在两侧（不对齐）→ 背压等待
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_APPLIER)
	_tick(3)
	assert_eq(_grid.count_items(), 0, "不对齐时物品不产生")
	assert_eq(_grid.count_edge_items(), 0, "不对齐不写入面槽")

func test_face_source_outputs_onto_belt_splitter_body() -> void:
	# 一体建筑 = 带子语义：机器输出落到其体格是网格物品（同相位被分流），不走面槽
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)  # 东口承接带
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 1), "物品应落到一体建筑格并被分流到承接带")
	assert_eq(_grid.count_edge_items(), 0, "一体建筑不走面槽")

func test_face_belt_splitter_feeds_adjacent_splitter() -> void:
	# 一体建筑作为面槽生产者：贴脸喂相邻分流器（互认对齐）→ 流向其承接带。
	# 回归：读侧曾整体排除一体建筑生产者，导致面物品永久不可读（隐形卡死）。
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(0, 0), Item.num(7))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 7), "一体建筑→筛选器 0 格贴脸应流动到通过口带子")
	assert_eq(_grid.count_edge_items(), 0, "面槽应被消费清空（回归：不得永久滞留）")
	_tick()
	assert_false(_grid.has_item(Vector2i(0, 0)), "一体建筑格物品应已被处理")

func test_face_splitter_outputs_to_adjacent_splitter() -> void:
	# 分流器(0,0) 东口 == 分流器(1,0) 本体格（互认贴合）→ 输出直传对方输入
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	_put(Vector2i(-1, 0), Item.num(3))
	_tick()
	assert_true(_has_num(Vector2i(2, 0), 3), "分流器→筛选器 0 格串链应流动")
	assert_eq(_grid.count_edge_items(), 0)

func test_face_events_carry_face_offset() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_SPLITTER)
	var events := _tick()
	var saw_face := false
	for e: Dictionary in events:
		if e.get("kind", "") == "spawn" and e.has("face"):
			saw_face = true
	assert_true(saw_face, "面直传 spawn 事件应带 face 偏移")

# ---------- 综合 ----------

func test_feedback_counter_reaches_five_without_leak() -> void:
	# 计数回路（纯函数式迭代）：初始 1 → 应用器 +1 → 反馈带绕回数据口，
	# 值每圈 +1。验证反馈带 = 迭代，且物品数量有界（背压不泄漏）。
	# 布局（输入口角色固定：数据口 ins[0]=(0,-1)，操作口 ins[1]=(0,1)）：
	#   应用器 (0,0) E：数据口 (0,-1)，操作口 (0,1)，出口 (1,0)
	#   反馈：出口 (1,0) E → (2,0) N → (2,-1) W → (1,-1) W → 数据口 (0,-1)
	#   操作物品由外部注入操作口 (0,1)（操作源建筑已移除，模拟外部 op 供给）
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_APPLIER, MachineSpec.DIR_E)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_N)
	_buildings[Vector2i(2, -1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_W)
	_buildings[Vector2i(1, -1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_W)
	_put(Vector2i(1, -1), Item.num(1))
	var events: Array[Dictionary] = []
	for i in range(30):
		events.append_array(ItemSimulator.tick(_buildings, _grid))
		# 操作口空则补一个 +1（外部供给模拟，替代已移除的操作源）
		if not _grid.has_item(Vector2i(0, 1)):
			_put(Vector2i(0, 1), Item.op(OpRegistry.OP_ADD1))
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