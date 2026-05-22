extends GutTest

const _SMScript = preload("res://scripts/autoload/selection_manager.gd")

func test_select_cell() -> void:
	SelectionManager.clear_selection()
	SelectionManager.select_cell(Vector2i(1, 1))
	assert_eq(SelectionManager.selected_cells.size(), 1, "选中后应有 1 个格子")
	assert_true(SelectionManager.selected_cells.has(Vector2i(1, 1)), "应包含 (1, 1)")

func test_select_multiple_cells() -> void:
	SelectionManager.clear_selection()
	SelectionManager.select_cell(Vector2i(0, 0))
	SelectionManager.select_cell(Vector2i(1, 0))
	SelectionManager.select_cell(Vector2i(0, 1))
	assert_eq(SelectionManager.selected_cells.size(), 3, "选中 3 个不同格子")

func test_deselect_cell() -> void:
	SelectionManager.clear_selection()
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
		cmd.buildings = {Vector2i(i, 0): {"type": "type_01"}}
		SelectionManager.push_undo_command(cmd)
	assert_eq(SelectionManager.undo_stack.size(), 100, "撤销栈大小应被限制为 100")

func test_paste_mode_default() -> void:
	SelectionManager.is_paste_mode = false
	SelectionManager.clipboard = {}
	assert_false(SelectionManager.is_paste_mode, "默认不应处于粘贴模式")
	assert_eq(SelectionManager.clipboard, {}, "默认剪贴板应为空")

func test_paste_mode_start_and_cancel() -> void:
	SelectionManager.clipboard = {"buildings": [ {"offset": Vector2i(0, 0), "type": "type_01"}]}
	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "start_paste_mode 应激活粘贴模式")
	SelectionManager.cancel_paste_mode()
	assert_false(SelectionManager.is_paste_mode, "cancel_paste_mode 应退出粘贴模式")

func test_copy_empty_selection() -> void:
	SelectionManager.selected_cells.clear()
	SelectionManager.clipboard = {}
	SelectionManager.copy_selection()
	assert_eq(SelectionManager.clipboard, {}, "空选择时 copy_selection 不应改变剪贴板")

func test_cut_empty_selection() -> void:
	var original_clipboard: Dictionary = SelectionManager.clipboard.duplicate(true)
	SelectionManager.selected_cells.clear()
	SelectionManager.cut_selection()
	assert_eq(SelectionManager.clipboard, original_clipboard, "空选择时 cut_selection 不应改变剪贴板")

func test_start_paste_empty_clipboard() -> void:
	SelectionManager.clipboard = {}
	SelectionManager.start_paste_mode()
	assert_false(SelectionManager.is_paste_mode, "空剪贴板时 start_paste_mode 不应激活粘贴模式")

func test_perform_paste_no_clipboard() -> void:
	SelectionManager.clipboard = {}
	SelectionManager.is_paste_mode = true
	SelectionManager.perform_paste(Vector2i(0, 0))
	assert_true(SelectionManager.is_paste_mode, "空剪贴板时 perform_paste 不应退出粘贴模式（因无 building_manager）")
	SelectionManager.is_paste_mode = false

func test_cancel_paste_emits_signal() -> void:
	watch_signals(EventBus)
	SelectionManager.clipboard = {"buildings": [ {"offset": Vector2i(0, 0), "type": "type_01"}]}
	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "应进入粘贴模式")
	SelectionManager.cancel_paste_mode()
	assert_signal_emitted(EventBus, "paste_mode_changed", "cancel_paste_mode 应发射 paste_mode_changed 信号")

func test_cut_undo_command_buildings_are_dictionaries() -> void:
	SelectionManager.undo_stack.clear()
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(1, 1): {"type": "type_01"}, Vector2i(2, 2): {"type": "type_02"}}
	SelectionManager.push_undo_command(cmd)
	var stored_cmd: UndoCommand = SelectionManager.undo_stack.back()
	assert_eq(stored_cmd.type, UndoCommand.Type.CUT, "撤销命令类型应为 CUT")
	for value: Dictionary in stored_cmd.buildings.values():
		assert_true(value is Dictionary, "buildings 值应为 Dictionary 类型")
		assert_true(value.has("type"), "Dictionary 应包含 type 键")

func test_select_rect_no_building_manager() -> void:
	SelectionManager.clear_selection()
	SelectionManager._building_manager = null
	var before := SelectionManager.selected_cells.size()
	SelectionManager.select_rect([Vector2i(0, 0), Vector2i(1, 1)])
	assert_eq(SelectionManager.selected_cells.size(), before, "无 building_manager 时 select_rect 不应增加选中")

func test_deselect_rect_removes_cells() -> void:
	SelectionManager.clear_selection()
	SelectionManager.select_cell(Vector2i(0, 0))
	SelectionManager.select_cell(Vector2i(1, 1))
	SelectionManager.select_cell(Vector2i(2, 2))
	assert_eq(SelectionManager.selected_cells.size(), 3, "初始应有 3 个选中格子")
	SelectionManager.deselect_rect([Vector2i(0, 0), Vector2i(2, 2)])
	assert_eq(SelectionManager.selected_cells.size(), 1, "deselect_rect 移除 2 个后应剩 1 个")
	assert_true(SelectionManager.selected_cells.has(Vector2i(1, 1)), "应保留 (1, 1)")
	assert_false(SelectionManager.selected_cells.has(Vector2i(0, 0)), "不应包含 (0, 0)")
	assert_false(SelectionManager.selected_cells.has(Vector2i(2, 2)), "不应包含 (2, 2)")

func test_undo_empty_stack_does_not_crash() -> void:
	SelectionManager.undo_stack.clear()
	SelectionManager.undo()
	assert_true(SelectionManager.undo_stack.is_empty(), "空撤销栈调用 undo() 不应崩溃")

func test_perform_paste_batch_with_building_manager() -> void:
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/ghost_preview_manager.gd")
	load("res://scripts/grid/input_state_machine.gd")
	load("res://scripts/grid/grid_coordinate.gd")
	load("res://scripts/fluid/fluid_coordinator.gd")
	var bm: BuildingManager = autoqfree(load("res://scripts/building/building_manager.gd").new())
	bm.name = "BuildingManager"

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	bm.add_child(pipe_render)
	bm.unique_name_in_owner = true
	add_child_autoqfree(bm)

	SelectionManager.undo_stack.clear()
	SelectionManager._building_manager = bm
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": GameConfig.container_type_id},
		{"offset": Vector2i(1, 0), "type": GameConfig.pipe_type_id},
	]
	SelectionManager.clipboard = {
		"buildings": buildings,
	}

	var anchors: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0)]
	SelectionManager.perform_paste_batch(anchors)

	assert_true(bm.has_building(Vector2i(0, 0)), "第一个锚点的 offset(0,0) 应放置建筑")
	assert_true(bm.has_building(Vector2i(1, 0)), "第一个锚点的 offset(1,0) 应放置建筑")
	assert_true(bm.has_building(Vector2i(3, 0)), "第二个锚点的 offset(0,0) 应放置建筑")
	assert_true(bm.has_building(Vector2i(4, 0)), "第二个锚点的 offset(1,0) 应放置建筑")

func test_perform_paste_batch_skip_occupied() -> void:
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/ghost_preview_manager.gd")
	load("res://scripts/grid/input_state_machine.gd")
	load("res://scripts/grid/grid_coordinate.gd")
	var bm: BuildingManager = autoqfree(load("res://scripts/building/building_manager.gd").new())
	bm.name = "BuildingManager"

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	bm.add_child(pipe_render)
	bm.unique_name_in_owner = true
	add_child_autoqfree(bm)

	SelectionManager.undo_stack.clear()
	SelectionManager._building_manager = bm
	bm.place_building(Vector2i(3, 0), GameConfig.container_type_id)

	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": GameConfig.container_type_id},
		{"offset": Vector2i(1, 0), "type": GameConfig.pipe_type_id},
	]
	SelectionManager.clipboard = {
		"buildings": buildings,
	}

	var anchors: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0)]
	SelectionManager.perform_paste_batch(anchors)

	assert_true(bm.has_building(Vector2i(0, 0)), "offset(0,0) 应放置")
	assert_true(bm.has_building(Vector2i(1, 0)), "offset(1,0) 应放置")
	assert_eq(bm.get_building_type(Vector2i(3, 0)), GameConfig.container_type_id, "已占用位置应保留原建筑")
	assert_true(bm.has_building(Vector2i(4, 0)), "第二个锚点的 offset(1,0) 应放置")

func test_perform_paste_batch_empty_clipboard() -> void:
	var bm: BuildingManager = autoqfree(load("res://scripts/building/building_manager.gd").new())
	bm.name = "BuildingManager"

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	bm.add_child(pipe_render)
	bm.unique_name_in_owner = true
	add_child_autoqfree(bm)

	SelectionManager._building_manager = bm
	SelectionManager.clipboard = {}

	var anchors: Array[Vector2i] = [Vector2i(0, 0)]
	SelectionManager.perform_paste_batch(anchors)

	assert_eq(bm.get_all_buildings_data().size(), 0, "空剪贴板不应放置任何建筑")

func test_redo_empty_stack_does_not_crash() -> void:
	SelectionManager.redo_stack.clear()
	SelectionManager.redo()
	assert_true(SelectionManager.redo_stack.is_empty(), "空 redo 栈调用 redo() 不应崩溃")

func test_new_action_clears_redo_stack() -> void:
	SelectionManager.redo_stack.clear()
	SelectionManager.redo_stack.append(UndoCommand.new())
	assert_eq(SelectionManager.redo_stack.size(), 1, "redo 栈应有 1 个元素")
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(0, 0): {"type": "type_01"}}
	SelectionManager.push_undo_command(cmd)
	assert_eq(SelectionManager.redo_stack.size(), 0, "新操作后 redo 栈应被清空")

func test_redo_after_undo_restores_building() -> void:
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/ghost_preview_manager.gd")
	load("res://scripts/grid/input_state_machine.gd")
	load("res://scripts/grid/grid_coordinate.gd")
	var bm: BuildingManager = autoqfree(load("res://scripts/building/building_manager.gd").new())
	bm.name = "BuildingManager"

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	bm.add_child(pipe_render)
	bm.unique_name_in_owner = true
	add_child_autoqfree(bm)

	SelectionManager.undo_stack.clear()
	SelectionManager.redo_stack.clear()
	SelectionManager._building_manager = bm

	bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(0, 0): {"type": GameConfig.container_type_id}}
	SelectionManager.push_undo_command(cmd)
	assert_true(bm.has_building(Vector2i(0, 0)), "放置后应有建筑")

	SelectionManager.undo()
	assert_false(bm.has_building(Vector2i(0, 0)), "undo 后建筑应被删除")
	assert_eq(SelectionManager.redo_stack.size(), 1, "undo 后 redo 栈应有 1 个元素")

	SelectionManager.redo()
	assert_true(bm.has_building(Vector2i(0, 0)), "redo 后建筑应被恢复")
	assert_eq(SelectionManager.undo_stack.size(), 1, "redo 后 undo 栈应有 1 个元素，可再次撤销")

func test_redo_undo_cycle() -> void:
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/ghost_preview_manager.gd")
	load("res://scripts/grid/input_state_machine.gd")
	load("res://scripts/grid/grid_coordinate.gd")
	var bm: BuildingManager = autoqfree(load("res://scripts/building/building_manager.gd").new())
	bm.name = "BuildingManager"

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	bm.add_child(pipe_render)
	bm.unique_name_in_owner = true
	add_child_autoqfree(bm)

	SelectionManager.undo_stack.clear()
	SelectionManager.redo_stack.clear()
	SelectionManager._building_manager = bm

	bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(0, 0): {"type": GameConfig.container_type_id}}
	SelectionManager.push_undo_command(cmd)

	SelectionManager.undo()
	assert_false(bm.has_building(Vector2i(0, 0)), "第1次 undo: 建筑应被删除")
	SelectionManager.redo()
	assert_true(bm.has_building(Vector2i(0, 0)), "第1次 redo: 建筑应被恢复")
	SelectionManager.undo()
	assert_false(bm.has_building(Vector2i(0, 0)), "第2次 undo: 建筑应再次被删除")
	SelectionManager.redo()
	assert_true(bm.has_building(Vector2i(0, 0)), "第2次 redo: 建筑应再次被恢复")

func test_rotate_clipboard_90_degrees() -> void:
	SelectionManager.is_paste_mode = true
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	SelectionManager.clipboard = {
		"buildings": buildings,
	}
	SelectionManager._paste_rotation = 0
	SelectionManager.rotate_clipboard()
	assert_eq(SelectionManager._paste_rotation, 1, "旋转后 _paste_rotation 应为 1（90°）")
	var effective := SelectionManager.get_effective_clipboard()
	assert_true(effective.has("buildings"), "旋转后应有 buildings")
	var offsets: Array[Vector2i] = []
	for item: Dictionary in effective.buildings:
		offsets.append(item.offset)
	assert_true(offsets.has(Vector2i(0, 0)), "90°旋转后 (0,0) 应不变")
	assert_true(offsets.has(Vector2i(0, 1)), "90°旋转后 (1,0) 应变为 (0,1)（重新归一化后）")

func test_rotate_clipboard_180_degrees() -> void:
	SelectionManager.is_paste_mode = true
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	SelectionManager.clipboard = {
		"buildings": buildings,
	}
	SelectionManager._paste_rotation = 0
	SelectionManager.rotate_clipboard()
	SelectionManager.rotate_clipboard()
	assert_eq(SelectionManager._paste_rotation, 2, "旋转 2 次后 _paste_rotation 应为 2（180°）")
	var effective := SelectionManager.get_effective_clipboard()
	var offsets: Array[Vector2i] = []
	for item: Dictionary in effective.buildings:
		offsets.append(item.offset)
	assert_true(offsets.has(Vector2i(0, 0)), "180°旋转后 (0,0) 不变")
	assert_true(offsets.has(Vector2i(1, 0)), "180°旋转后 (1,0) 归一化为 (0,0) 和 (1,0)")

func test_rotate_clipboard_360_returns_to_original() -> void:
	SelectionManager.is_paste_mode = true
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	SelectionManager.clipboard = {
		"buildings": buildings,
	}
	SelectionManager._paste_rotation = 0
	for _i in 4:
		SelectionManager.rotate_clipboard()
	assert_eq(SelectionManager._paste_rotation, 0, "旋转 4 次后 _paste_rotation 应回到 0")
	var effective := SelectionManager.get_effective_clipboard()
	var cb_buildings: Array[Dictionary] = effective.buildings
	assert_eq(cb_buildings.size(), 2, "旋转4次后剪贴板大小不变")
	assert_eq(cb_buildings[0].offset, Vector2i(0, 0), "旋转4次后 (0,0) 不变")
	assert_eq(cb_buildings[1].offset, Vector2i(1, 0), "旋转4次后 (1,0) 不变")

func test_rotate_clipboard_empty_clipboard() -> void:
	SelectionManager.is_paste_mode = true
	SelectionManager.clipboard = {}
	SelectionManager._paste_rotation = 0
	SelectionManager.rotate_clipboard()
	assert_true(true, "空剪贴板旋转不应崩溃")

func test_rotate_clipboard_single_cell() -> void:
	SelectionManager.is_paste_mode = true
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(2, 3), "type": "type_01"},
	]
	SelectionManager.clipboard = {
		"buildings": buildings,
	}
	SelectionManager._paste_rotation = 0
	SelectionManager.rotate_clipboard()
	assert_eq(SelectionManager._paste_rotation, 1, "旋转后 _paste_rotation 应为 1")
	var raw_offset := _SMScript._rotate_offset(Vector2i(2, 3), 1)
	assert_eq(raw_offset, Vector2i(-3, 2), "_rotate_offset(2,3,1) 应返回 (-3,2)")
	var effective := SelectionManager.get_effective_clipboard()
	assert_true(effective.has("buildings"), "旋转后应有 buildings")
	assert_eq(effective.buildings[0].type, "type_01", "类型应保持不变")
