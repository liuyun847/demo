extends GutTest

## BeltConnection 连接分析单元测试：带子连接/转向视觉的数据源。

var _buildings: Dictionary = {}

func before_each() -> void:
	_buildings = {}

func after_each() -> void:
	_buildings = {}

func _bd(type_id: String, dir: int = MachineSpec.DIR_E) -> BuildingData:
	var d := BuildingData.new()
	d.building_type = type_id
	d.direction = dir
	return d

func _info(cell: Vector2i) -> Dictionary:
	var computed := BeltConnection.compute(_buildings)
	return computed.get(cell, {})

# ---------- 基本连接 ----------

func test_straight_chain_links_back_and_front() -> void:
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	var info: Dictionary = _info(Vector2i(2, 0))
	assert_eq(info.get("feed", -99), MachineSpec.DIR_W, "下游带应被同向上游带喂入")
	assert_eq(info.get("exits", []), [MachineSpec.DIR_E], "出口 = 自身方向")
	assert_eq(info.get("taps", []), [], "无机器抽取")
	assert_eq(info.get("fed_by", []), [], "无机器供给")

func test_first_belt_of_chain_no_feed() -> void:
	# 直线链首带：无带子上游（机器供给只记录 fed_by，不算 feed）
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, 0)] = _bd(MachineSpec.T_BELT)
	var info: Dictionary = _info(Vector2i(1, 0))
	assert_eq(info.get("feed", -99), BeltConnection.NO_FEED, "首带无上游带子")
	assert_eq(info.get("fed_by", []), [], "首带也无机器供给")

func test_corner_turn_geometry() -> void:
	# 存档第二行合流布局: (2,-4) E → (3,-4) S → (3,-3) E
	_buildings[Vector2i(2, -4)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_buildings[Vector2i(3, -4)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(3, -3)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	var info34: Dictionary = _info(Vector2i(3, -4))
	assert_eq(info34.get("feed", -99), MachineSpec.DIR_W, "拐角带从西侧被喂入")
	assert_eq(info34.get("feeds", []), [MachineSpec.DIR_W])
	assert_eq(info34.get("exits", []), [MachineSpec.DIR_S], "拐角带向南出")
	var info33: Dictionary = _info(Vector2i(3, -3))
	assert_eq(info33.get("feed", -99), MachineSpec.DIR_N, "北向带喂入同向输出带（T 合流角）")
	assert_eq(info33.get("exits", []), [MachineSpec.DIR_E])

func test_merge_cell_records_all_feeds() -> void:
	# 西带朝 E 与 北带朝 S 同时喂入同一带格: feeds 应记录两条喂入边
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	_buildings[Vector2i(1, -1)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_S)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT, MachineSpec.DIR_E)
	var info: Dictionary = _info(Vector2i(1, 0))
	assert_eq(info.get("feeds", []), [MachineSpec.DIR_W, MachineSpec.DIR_N], "合流格应记录两条喂入边")
	assert_eq(info.get("feed", -99), MachineSpec.DIR_W, "主喂入边=第一条（扫描序 E→S→W→N）")

func test_dead_end_belt_keeps_exit() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	var info: Dictionary = _info(Vector2i(0, 0))
	assert_eq(info.get("exits", []), [MachineSpec.DIR_E], "孤立带仍指向自身方向")
	assert_eq(info.get("feed", -99), BeltConnection.NO_FEED)

# ---------- 机器供给 / 抽取 ----------

func test_machine_output_feeds_belt_cell() -> void:
	# 数字源(0,-1) E 输出口 == 带格 (1,-1)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, -1)] = _bd(MachineSpec.T_BELT)
	var info: Dictionary = _info(Vector2i(1, -1))
	assert_eq(info.get("fed_by", []), [Vector2i(-1, 0)], "数字源输出口应喂入带格（fed_by 记录相对偏移）")
	assert_eq(info.get("feed", -99), BeltConnection.NO_FEED, "机器供给不算带子上游（band 从中心起画）")

func test_belt_cell_as_machine_input_taps() -> void:
	# 存档第一行: 带格 (1,-3) 是分流器 (2,-3) 的输入口 → 顺带抽取（T 形支路）
	_buildings[Vector2i(1, -3)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, -3)] = _bd(MachineSpec.T_SPLITTER)
	var info: Dictionary = _info(Vector2i(1, -3))
	assert_eq(info.get("taps", []), [Vector2i(1, 0)], "带格是机器输入口 → taps 记录机器相对偏移")

func test_num_source_feeds_any_adjacent_belt_cell() -> void:
	# 数字源（无方向）：四周相邻带格全部视为被喂入（fed_by），无需对齐输出口
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_NUM_SOURCE)  # 源在北侧
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	var info: Dictionary = _info(Vector2i(0, 0))
	assert_eq(info.get("fed_by", []), [Vector2i(0, -1)], "源在北侧 → 带格 fed_by 记录相对偏移")
	assert_eq(info.get("feed", -99), BeltConnection.NO_FEED, "数字源不是带子上游（band 从中心起画）")

func test_num_source_does_not_tap_belt() -> void:
	# 数字源无输入口：相邻带格不应产生 taps（抽取）支路
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	var info: Dictionary = _info(Vector2i(1, 0))
	assert_eq(info.get("taps", []), [], "数字源不抽取带格物品")
	assert_eq(info.get("fed_by", []), [Vector2i(-1, 0)], "源应喂入相邻带格")

func test_belt_splitter_four_exits() -> void:
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	var info: Dictionary = _info(Vector2i(1, 0))
	assert_eq(info.get("feed", -99), MachineSpec.DIR_W, "上游带喂入一体建筑")
	assert_eq(info.get("exits", []), [MachineSpec.DIR_E, MachineSpec.DIR_S, MachineSpec.DIR_W, MachineSpec.DIR_N], "一体建筑出口 = 四向")

func test_belt_splitter_body_receives_machine_output() -> void:
	# 一体建筑格是带子语义：分流器四向输入口覆盖一体建筑格 → 保留 taps（可能抽取）；
	# 分流器输出不定向（轮询）→ 不画 fed_by
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT_SPLITTER)
	var info: Dictionary = _info(Vector2i(1, 0))
	assert_eq(info.get("fed_by", []), [], "四向分流器不画 fed_by（输出不定向）")
	assert_eq(info.get("taps", []), [Vector2i(-1, 0)], "四向分流器 ins 覆盖 → 保留 taps（可能抽取）")

func test_trash_does_not_tap_belt() -> void:
	# 垃圾桶不从带格顺带抽取（输入=本体格推入/面槽投递）：相邻带格不应产生 taps
	_buildings[Vector2i(0, 0)] = _bd(MachineSpec.T_TRASH)
	_buildings[Vector2i(1, 0)] = _bd(MachineSpec.T_BELT)
	var info: Dictionary = _info(Vector2i(1, 0))
	assert_eq(info.get("taps", []), [], "垃圾桶不抽取带格物品")
	assert_eq(info.get("fed_by", []), [], "垃圾桶无输出，不画 fed_by")

func test_taps_fed_by_offsets_are_axial() -> void:
	# 回归防护：绘制端把 taps/fed_by 当方向向量用，存储必须是四方向单位偏移
	# （曾误存机器格子坐标，绘制时画出节点外的 45° 白条/超长支路）
	var axial: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	_buildings[Vector2i(1, -3)] = _bd(MachineSpec.T_BELT)
	_buildings[Vector2i(2, -3)] = _bd(MachineSpec.T_SPLITTER)
	_buildings[Vector2i(0, -1)] = _bd(MachineSpec.T_NUM_SOURCE)
	_buildings[Vector2i(1, -1)] = _bd(MachineSpec.T_BELT)
	var computed := BeltConnection.compute(_buildings)
	for cell: Vector2i in computed.keys():
		var info: Dictionary = computed[cell]
		for tap: Vector2i in info.get("taps", []):
			assert_true(axial.has(tap), "taps 偏移必须是轴向单位向量: %s" % str(tap))
		for fed: Vector2i in info.get("fed_by", []):
			assert_true(axial.has(fed), "fed_by 偏移必须是轴向单位向量: %s" % str(fed))

func test_compute_skips_empty() -> void:
	var computed := BeltConnection.compute(_buildings)
	assert_eq(computed.size(), 0, "空建筑集返回空结果")
	computed = BeltConnection.compute({Vector2i(3, 3): _bd(MachineSpec.T_APPLIER)})
	assert_eq(computed.size(), 0, "非带子建筑不进入连接表")
