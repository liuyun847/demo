extends GutTest

const _SMScript = preload("res://scripts/autoload/selection_manager.gd")

var _bm: BuildingManager = null


func before_all() -> void:
	BuildingTypeManager.register_defaults()

func before_each() -> void:
	_bm = autoqfree(BuildingManager.new())
	add_child_autoqfree(_bm)
	SelectionManager._building_manager = _bm
	SelectionManager.clear_selection()
	SelectionManager.clipboard = {}
	SelectionManager.is_paste_mode = false

func test_select_cell() -> void:
	SelectionManager.select_cell(Vector2i(1, 1))
	assert_eq(SelectionManager.selected_cells.size(), 1, "选中后应有 1 个格子")
	assert_true(SelectionManager.selected_cells.has(Vector2i(1, 1)), "应包含 (1, 1)")

func test_select_multiple_cells() -> void:
	SelectionManager.select_cell(Vector2i(0, 0))
	SelectionManager.select_cell(Vector2i(1, 0))
	SelectionManager.select_cell(Vector2i(0, 1))
	assert_eq(SelectionManager.selected_cells.size(), 3, "选中 3 个不同格子")

func test_deselect_cell() -> void:
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.deselect_cell(Vector2i(5, 5))
	assert_false(SelectionManager.selected_cells.has(Vector2i(5, 5)), "取消选中后不应包含")

func test_clear_selection() -> void:
	SelectionManager.select_cell(Vector2i(2, 2))
	SelectionManager.select_cell(Vector2i(3, 3))
	SelectionManager.clear_selection()
	assert_true(SelectionManager.selected_cells.is_empty(), "清除后应为空")

func test_undo_stack_max_size() -> void:
	SelectionManager.undo_stack.clear()
	for i in range(110):
		var cmd: UndoCommand = UndoCommand.new()
		cmd.type = UndoCommand.Type.PLACE
		cmd.buildings = {Vector2i(i, 0): {"type": MachineSpec.T_BELT}}
		SelectionManager.push_undo_command(cmd)
	assert_eq(SelectionManager.undo_stack.size(), 100, "撤销栈大小应被限制为 100")

func test_paste_mode_default() -> void:
	assert_false(SelectionManager.is_paste_mode, "默认不应处于粘贴模式")
	assert_eq(SelectionManager.clipboard, {}, "默认剪贴板应为空")

func test_paste_mode_start_and_cancel() -> void:
	SelectionManager.clipboard = {"buildings": [{"offset": Vector2i(0, 0), "type": MachineSpec.T_BELT}]}
	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "start_paste_mode 应激活粘贴模式")
	SelectionManager.cancel_paste_mode()
	assert_false(SelectionManager.is_paste_mode, "cancel_paste_mode 应退出粘贴模式")

func test_start_paste_empty_clipboard() -> void:
	SelectionManager.start_paste_mode()
	assert_false(SelectionManager.is_paste_mode, "空剪贴板时 start_paste_mode 不应激活粘贴模式")

func test_cancel_paste_emits_signal() -> void:
	watch_signals(EventBus)
	SelectionManager.clipboard = {"buildings": [{"offset": Vector2i(0, 0), "type": MachineSpec.T_BELT}]}
	SelectionManager.start_paste_mode()
	SelectionManager.cancel_paste_mode()
	assert_signal_emitted(EventBus, "paste_mode_changed", "cancel_paste_mode 应发射 paste_mode_changed 信号")

# ---------- 复制/剪切/粘贴（含物品流字段） ----------

func test_copy_selection_captures_direction() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_N})
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.copy_selection()
	var buildings: Array = SelectionManager.clipboard.buildings
	assert_eq(buildings.size(), 1, "剪贴板应有 1 个建筑")
	var entry: Dictionary = buildings[0]
	assert_eq(entry.type, MachineSpec.T_BELT)
	assert_eq(entry.direction, MachineSpec.DIR_N, "复制应携带朝向")

func test_copy_selection_captures_op_choice() -> void:
	# op_choice 字段保留（通用容器/旧存档兼容），用应用器验证复制携带
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_APPLIER, {"op_choice": OpRegistry.OP_MUL2})
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.copy_selection()
	var entry: Dictionary = SelectionManager.clipboard.buildings[0]
	assert_eq(entry.op_choice, OpRegistry.OP_MUL2, "复制应携带操作选择")

func test_paste_restores_direction() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_W})
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.copy_selection()
	SelectionManager.start_paste_mode()
	SelectionManager.perform_paste(Vector2i(20, 20))
	assert_true(_bm.has_building(Vector2i(20, 20)), "粘贴应放置建筑")
	assert_eq(_bm.get_building_data(Vector2i(20, 20)).direction, MachineSpec.DIR_W, "粘贴应还原朝向")

func test_paste_batch_restores_fields() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_SPLITTER, {
		"direction": MachineSpec.DIR_S,
		"splitter_filters": [{}, {"kind": "num", "cmp": "lt", "value": 3}, {}, {}],
	})
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.copy_selection()
	SelectionManager.start_paste_mode()
	SelectionManager.perform_paste_batch([Vector2i(30, 30)])
	var data: BuildingData = _bm.get_building_data(Vector2i(30, 30))
	assert_eq(data.direction, MachineSpec.DIR_S, "粘贴应还原朝向")
	assert_eq(int(data.splitter_filters[1].get("value", -1)), 3, "粘贴应还原南向条件值")
	assert_eq(str(data.splitter_filters[1].get("cmp", "")), "lt", "粘贴应还原南向条件比较")

func test_cut_then_undo_restores_fields() -> void:
	_bm.place_building(Vector2i(7, 7), MachineSpec.T_SPLITTER, {"splitter_phase": 1, "direction": MachineSpec.DIR_N})
	SelectionManager.select_cell(Vector2i(7, 7))
	SelectionManager.cut_selection()
	assert_false(_bm.has_building(Vector2i(7, 7)), "剪切后建筑应移除")
	SelectionManager.undo()
	assert_true(_bm.has_building(Vector2i(7, 7)), "撤销应恢复建筑")
	var data: BuildingData = _bm.get_building_data(Vector2i(7, 7))
	assert_eq(data.splitter_phase, 1, "撤销应恢复分流交替位")
	assert_eq(data.direction, MachineSpec.DIR_N, "撤销应恢复朝向")

func test_undo_redo_place_then_remove() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(5, 5): {"type": MachineSpec.T_BELT}}
	SelectionManager.push_undo_command(cmd)
	SelectionManager.undo()
	assert_false(_bm.has_building(Vector2i(5, 5)), "撤销放置应移除")
	SelectionManager.redo()
	assert_true(_bm.has_building(Vector2i(5, 5)), "重做应恢复放置")

# ---------- 分流器放传送带（一体建筑）撤销/粘贴 ----------

func test_undo_place_splitter_on_belt_restores_belt() -> void:
	# 撤销"放分流器到传送带上"应还原原传送带（而非把带子一并删掉）
	_bm.place_building(Vector2i(7, 7), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_N})
	var ok: bool = _bm.place_building(Vector2i(7, 7), MachineSpec.T_SPLITTER, {"direction": MachineSpec.DIR_N})
	assert_true(ok)
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(7, 7): {"type": MachineSpec.T_SPLITTER, "direction": MachineSpec.DIR_N}}
	cmd.previous = {Vector2i(7, 7): {"type": MachineSpec.T_BELT, "direction": MachineSpec.DIR_N}}
	SelectionManager.push_undo_command(cmd)
	SelectionManager.undo()
	assert_eq(_bm.get_building_type(Vector2i(7, 7)), MachineSpec.T_BELT, "撤销放置应还原原传送带")
	assert_eq(_bm.get_building_data(Vector2i(7, 7)).direction, MachineSpec.DIR_N)
	SelectionManager.redo()
	assert_eq(_bm.get_building_type(Vector2i(7, 7)), MachineSpec.T_BELT_SPLITTER, "重做应恢复一体建筑")

func test_undo_remove_belt_splitter_restores_combo() -> void:
	# 删除一体建筑（带子一并删除）后撤销应恢复组合（含交替位/方向）
	_bm.place_building(Vector2i(7, 7), MachineSpec.T_BELT_SPLITTER, {"direction": MachineSpec.DIR_S, "splitter_phase": 1})
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.REMOVE
	cmd.buildings = {Vector2i(7, 7): {"type": MachineSpec.T_BELT_SPLITTER, "direction": MachineSpec.DIR_S, "splitter_phase": 1}}
	SelectionManager.push_undo_command(cmd)
	SelectionManager.undo()
	assert_true(_bm.has_building(Vector2i(7, 7)), "撤销删除应恢复一体建筑")
	var data: BuildingData = _bm.get_building_data(Vector2i(7, 7))
	assert_eq(data.building_type, MachineSpec.T_BELT_SPLITTER)
	assert_eq(data.direction, MachineSpec.DIR_S)
	assert_eq(data.splitter_phase, 1, "撤销应恢复交替位")

func test_paste_splitter_onto_belt_converts_then_undo_restores_belt() -> void:
	# 粘贴分流器到已有传送带格：转换一体建筑；撤销应还原原传送带
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_N})
	_bm.place_building(Vector2i(10, 10), MachineSpec.T_SPLITTER, {"direction": MachineSpec.DIR_W})
	SelectionManager.select_cell(Vector2i(10, 10))
	SelectionManager.copy_selection()
	SelectionManager.start_paste_mode()
	SelectionManager.perform_paste(Vector2i(5, 5))
	assert_eq(_bm.get_building_type(Vector2i(5, 5)), MachineSpec.T_BELT_SPLITTER, "粘贴到带格应转换一体建筑")
	SelectionManager.undo()
	assert_eq(_bm.get_building_type(Vector2i(5, 5)), MachineSpec.T_BELT, "撤销粘贴应还原原传送带")
	assert_eq(_bm.get_building_data(Vector2i(5, 5)).direction, MachineSpec.DIR_N)

func test_rotate_clipboard_rotates_direction() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_E})
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.copy_selection()
	SelectionManager.start_paste_mode()
	SelectionManager.rotate_clipboard()
	var effective := SelectionManager.get_effective_clipboard()
	var entry: Dictionary = effective.buildings[0]
	assert_eq(entry.direction, MachineSpec.DIR_S, "粘贴旋转 90° 应同步旋转朝向")

func test_select_rect_no_building_manager() -> void:
	SelectionManager._building_manager = null
	var before := SelectionManager.selected_cells.size()
	SelectionManager.select_rect([Vector2i(0, 0), Vector2i(1, 1)])
	assert_eq(SelectionManager.selected_cells.size(), before, "无 building_manager 时 select_rect 不应增加选中")