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
	# 东向：输入端=后格，输出端=前(东)/左(北)——与普通分流器同端口布局
	var ports: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_BELT_SPLITTER, MachineSpec.DIR_E)
	assert_eq(ports["ins"], [Vector2i(-1, 0)])
	assert_eq(ports["outs"], [Vector2i(1, 0), Vector2i(0, -1)])

func test_belt_splitter_port_offsets_rotated() -> void:
	# 南向（旋转 1 次）：前=南(0,1)，左=东(1,0)
	var ports: Dictionary = MachineSpec.get_port_offsets(MachineSpec.T_BELT_SPLITTER, MachineSpec.DIR_S)
	assert_eq(ports["outs"], [Vector2i(0, 1), Vector2i(1, 0)])

func test_belt_splitter_display_name() -> void:
	assert_eq(MachineSpec.get_display_name(MachineSpec.T_BELT_SPLITTER), "分流器(传送带)")

func test_belt_splitter_not_in_placement_types() -> void:
	# 一体建筑不进库存栏（由"分流器放传送带"/存档恢复自动生成）
	assert_false(MachineSpec.get_placement_types().has(MachineSpec.T_BELT_SPLITTER), "不应出现在放置类型列表")
