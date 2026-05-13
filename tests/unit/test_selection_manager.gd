extends GutTest

func test_select_cell():
	SelectionManager.clear_selection()
	SelectionManager.select_cell(Vector2i(1, 1))
	assert_eq(SelectionManager.selected_cells.size(), 1, "选中后应有 1 个格子")
	assert_true(SelectionManager.selected_cells.has(Vector2i(1, 1)), "应包含 (1, 1)")

func test_select_multiple_cells():
	SelectionManager.clear_selection()
	SelectionManager.select_cell(Vector2i(0, 0))
	SelectionManager.select_cell(Vector2i(1, 0))
	SelectionManager.select_cell(Vector2i(0, 1))
	assert_eq(SelectionManager.selected_cells.size(), 3, "选中 3 个不同格子")

func test_deselect_cell():
	SelectionManager.clear_selection()
	SelectionManager.select_cell(Vector2i(5, 5))
	SelectionManager.deselect_cell(Vector2i(5, 5))
	assert_false(SelectionManager.selected_cells.has(Vector2i(5, 5)), "取消选中后不应包含")

func test_clear_selection():
	SelectionManager.select_cell(Vector2i(2, 2))
	SelectionManager.select_cell(Vector2i(3, 3))
	SelectionManager.clear_selection()
	assert_true(SelectionManager.selected_cells.is_empty(), "清除后应为空")

func test_undo_stack_max_size():
	SelectionManager.undo_stack.clear()
	for i in range(110):
		var cmd = UndoCommand.new()
		cmd.type = UndoCommand.Type.PLACE
		cmd.buildings = {Vector2i(i, 0): "type_01"}
		SelectionManager.push_undo_command(cmd)
	assert_eq(SelectionManager.undo_stack.size(), 100, "撤销栈大小应被限制为 100")

func test_paste_mode_default():
	SelectionManager.is_paste_mode = false
	SelectionManager.clipboard = {}
	assert_false(SelectionManager.is_paste_mode, "默认不应处于粘贴模式")
	assert_eq(SelectionManager.clipboard, {}, "默认剪贴板应为空")

func test_paste_mode_start_and_cancel():
	SelectionManager.clipboard = {"buildings": [{"offset": Vector2i(0, 0), "type": "type_01"}]}
	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "start_paste_mode 应激活粘贴模式")
	SelectionManager.cancel_paste_mode()
	assert_false(SelectionManager.is_paste_mode, "cancel_paste_mode 应退出粘贴模式")

func test_copy_empty_selection():
	SelectionManager.selected_cells.clear()
	SelectionManager.clipboard = {}
	SelectionManager.copy_selection()
	assert_eq(SelectionManager.clipboard, {}, "空选择时 copy_selection 不应改变剪贴板")

func test_cut_empty_selection():
	var original_clipboard = SelectionManager.clipboard.duplicate(true)
	SelectionManager.selected_cells.clear()
	SelectionManager.cut_selection()
	assert_eq(SelectionManager.clipboard, original_clipboard, "空选择时 cut_selection 不应改变剪贴板")

func test_start_paste_empty_clipboard():
	SelectionManager.clipboard = {}
	SelectionManager.start_paste_mode()
	assert_false(SelectionManager.is_paste_mode, "空剪贴板时 start_paste_mode 不应激活粘贴模式")

func test_perform_paste_no_clipboard():
	SelectionManager.clipboard = {}
	SelectionManager.is_paste_mode = true
	SelectionManager.perform_paste(Vector2i(0, 0))
	assert_true(SelectionManager.is_paste_mode, "空剪贴板时 perform_paste 不应退出粘贴模式（因无 building_manager）")

func test_cancel_paste_emits_signal():
	watch_signals(EventBus)
	SelectionManager.clipboard = {"buildings": [{"offset": Vector2i(0, 0), "type": "type_01"}]}
	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "应进入粘贴模式")
	SelectionManager.cancel_paste_mode()
	assert_signal_emitted(EventBus, "paste_mode_changed", "cancel_paste_mode 应发射 paste_mode_changed 信号")

func test_cut_undo_command_buildings_are_strings():
	SelectionManager.undo_stack.clear()
	var cmd := UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(1, 1): "type_01", Vector2i(2, 2): "type_02"}
	SelectionManager.push_undo_command(cmd)
	var stored_cmd: UndoCommand = SelectionManager.undo_stack.back()
	assert_eq(stored_cmd.type, UndoCommand.Type.CUT, "撤销命令类型应为 CUT")
	for value in stored_cmd.buildings.values():
		assert_true(value is String, "buildings 值应为纯 String 而非 Dictionary，不应包含 capacity")

func test_select_rect_no_building_manager():
	SelectionManager.clear_selection()
	SelectionManager._building_manager = null
	var before := SelectionManager.selected_cells.size()
	SelectionManager.select_rect([Vector2i(0, 0), Vector2i(1, 1)])
	assert_eq(SelectionManager.selected_cells.size(), before, "无 building_manager 时 select_rect 不应增加选中")

func test_deselect_rect_removes_cells():
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

func test_undo_empty_stack_does_not_crash():
	SelectionManager.undo_stack.clear()
	SelectionManager.undo()
	assert_true(SelectionManager.undo_stack.is_empty(), "空撤销栈调用 undo() 不应崩溃")

func test_perform_paste_batch_with_building_manager():
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/water_source_node.gd")
	load("res://scripts/building/fluid_node_base.gd")
	var bm = autoqfree(load("res://scripts/building/building_manager.gd").new())
	add_child_autoqfree(bm)
	bm.name = "BuildingManager"
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

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

func test_perform_paste_batch_skip_occupied():
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/water_source_node.gd")
	load("res://scripts/building/fluid_node_base.gd")
	var bm = autoqfree(load("res://scripts/building/building_manager.gd").new())
	add_child_autoqfree(bm)
	bm.name = "BuildingManager"
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

	SelectionManager.undo_stack.clear()
	SelectionManager._building_manager = bm
	bm.place_building(Vector2i(3, 0), GameConfig.water_source_type_id)

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
	assert_eq(bm.get_building_type(Vector2i(3, 0)), GameConfig.water_source_type_id, "已占用位置应保留原建筑")
	assert_true(bm.has_building(Vector2i(4, 0)), "第二个锚点的 offset(1,0) 应放置")

func test_perform_paste_batch_empty_clipboard():
	var bm = autoqfree(load("res://scripts/building/building_manager.gd").new())
	add_child_autoqfree(bm)
	bm.name = "BuildingManager"
	SelectionManager._building_manager = bm
	SelectionManager.clipboard = {}

	var anchors: Array[Vector2i] = [Vector2i(0, 0)]
	SelectionManager.perform_paste_batch(anchors)

	assert_eq(bm.get_all_buildings_data().size(), 0, "空剪贴板不应放置任何建筑")


