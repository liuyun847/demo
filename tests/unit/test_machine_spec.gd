extends GutTest

## MachineSpec 规格表测试：新增"传送带+分流器一体建筑"类型。

func test_belt_splitter_registered_as_machine() -> void:
	var spec: Dictionary = MachineSpec.get_spec(MachineSpec.T_BELT_SPLITTER)
	assert_eq(spec.get("kind", ""), MachineSpec.KIND_BELT_SPLITTER, "一体建筑 kind 应为 belt_splitter")
	assert_true(MachineSpec.is_machine(MachineSpec.T_BELT_SPLITTER), "应视为机器")
	assert_true(MachineSpec.is_belt_splitter(MachineSpec.T_BELT_SPLITTER), "is_belt_splitter 应识别")
	assert_false(MachineSpec.is_belt(MachineSpec.T_BELT_SPLITTER), "不是纯传送带类型")
	assert_true(MachineSpec.is_known(MachineSpec.T_BELT_SPLITTER), "应为已知类型")

func test_belt_splitter_port_offsets_east() -> void:
	# 四向：4 个方向口完全对称 [E,S,W,N]，与普通分流器一致（不区分输入输出）
	var ports: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_BELT_SPLITTER, MachineSpec.DIR_E)
	assert_eq(ports["ins"], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)])
	assert_eq(ports["outs"], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)])

func test_belt_splitter_port_offsets_rotated() -> void:
	# 任意方向（旋转）四向端口保持对称不变
	var ports: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_BELT_SPLITTER, MachineSpec.DIR_S)
	assert_eq(ports["outs"], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)])

func test_splitter_four_way_ports() -> void:
	# 四向分流器：4 个方向口完全对称（任意方向旋转结果一致）
	for dir: int in [MachineSpec.DIR_E, MachineSpec.DIR_S, MachineSpec.DIR_W, MachineSpec.DIR_N]:
		var ports: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_SPLITTER, dir)
		assert_eq(ports["ins"], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)], "ins 四向端口应对称")
		assert_eq(ports["outs"], [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)], "outs 四向端口应对称")

func test_belt_splitter_display_name() -> void:
	assert_eq(MachineSpec.get_display_name(MachineSpec.T_BELT_SPLITTER), "分流器(传送带)")

func test_belt_splitter_not_in_placement_types() -> void:
	# 一体建筑不进库存栏（由"分流器放传送带"/存档恢复自动生成）
	assert_false(MachineSpec.get_placement_types().has(MachineSpec.T_BELT_SPLITTER), "不应出现在放置类型列表")

# ---------- 数字源无方向 ----------

func test_num_source_no_fixed_direction_ports() -> void:
	# 数字源无方向：SPECS 无固定输出口，端口偏移统一视图返回空端口（预览不画方向箭头）
	var spec: Dictionary = MachineSpec.get_spec(MachineSpec.T_NUM_SOURCE)
	assert_eq(spec.get("ins", "missing"), [], "数字源无输入口")
	assert_eq(spec.get("outs", "missing"), [], "数字源无固定输出口")
	var ports: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_NUM_SOURCE, MachineSpec.DIR_E)
	assert_eq(ports["ins"], [], "无方向源的端口偏移 ins 应为空")
	assert_eq(ports["outs"], [], "无方向源的端口偏移 outs 应为空")
	# 任意方向（旋转）都同样无端口
	var ports_n: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_NUM_SOURCE, MachineSpec.DIR_N)
	assert_eq(ports_n["ins"], [], "北向同样无端口")
	assert_eq(ports_n["outs"], [], "北向同样无端口")
