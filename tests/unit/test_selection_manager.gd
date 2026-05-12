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
