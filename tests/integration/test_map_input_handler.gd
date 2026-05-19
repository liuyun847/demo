extends GutTest

var _bm: Node2D = null
var _handler: Node = null
var _bar: InventoryBar = null
var _camera: Camera2D = null

func before_each() -> void:
	preload("res://scripts/building/fluid_node_base.gd")
	preload("res://scripts/building/container_node.gd")
	preload("res://scripts/building/pipe_node.gd")
	preload("res://scripts/building/water_source_node.gd")
	preload("res://scripts/resources/building_data.gd")
	preload("res://scripts/resources/undo_command.gd")
	preload("res://scripts/grid/input_state_machine.gd")
	preload("res://scripts/building/ghost_preview_manager.gd")
	preload("res://scripts/building/brick_node.gd")

	_camera = autoqfree(Camera2D.new())
	_camera.enabled = true
	add_child_autoqfree(_camera)

	var bm_script: GDScript = preload("res://scripts/building/building_manager.gd")
	_bm = autoqfree(bm_script.new())
	_bm.name = "BuildingManager"
	_bm.unique_name_in_owner = true

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	_bm.add_child(pipe_render)

	var gp: GhostPreviewManager = autoqfree(load("res://scripts/building/ghost_preview_manager.gd").new())
	gp.name = "GhostPreviewManager"
	_bm.add_child(gp)

	add_child_autoqfree(_bm)

	_bar = autoqfree(preload("res://scripts/ui/inventory_bar.gd").new())
	_bar.name = "InventoryBar"
	add_child_autoqfree(_bar)

	var handler_script: GDScript = preload("res://scripts/grid/map_input_handler.gd")
	_handler = autoqfree(handler_script.new())
	_handler.building_manager = _bm
	_handler.inventory_bar = _bar
	add_child_autoqfree(_handler)

	SelectionManager.clear_selection()
	SelectionManager.clipboard = {}

func after_each() -> void:
	SelectionManager.clipboard = {}
	SelectionManager.undo_stack.clear()
	SelectionManager._building_manager = null

func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	return GridCoordinate.screen_to_grid(_camera, screen_pos)

func _make_mouse_event(button_index: int, pressed: bool, pos: Vector2 = Vector2(320, 240)) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	return event

func _make_clipboard() -> Dictionary:
	var buildings: Array[Dictionary] = []
	buildings.append({"offset": Vector2i(0, 0), "type": GameConfig.container_type_id})
	buildings.append({"offset": Vector2i(1, 0), "type": GameConfig.pipe_type_id})
	return {"buildings": buildings}

func test_place_single_building() -> void:
	_bar.select_slot(0)
	var building_type: String = _bar.get_current_building_type()
	assert_ne(building_type, "default", "选中槽位后应返回非 default 的类型")

	var grid_pos := Vector2i(10, 10)
	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)

	_handler._handle_building_mode(event_press, grid_pos, get_viewport())
	_handler._handle_building_mode(event_release, grid_pos, get_viewport())

	assert_true(_bm.has_building(grid_pos), "左键单击后建筑应放置在 (10, 10)")
	assert_eq(_bm.buildings[grid_pos].building_type, building_type, "建筑类型应与选中槽位一致")

func test_place_building_line_drag() -> void:
	_bar.select_slot(1)

	var start := Vector2i(0, 0)
	var end := Vector2i(4, 0)

	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	_handler._handle_building_mode(event_press, start, get_viewport())

	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)
	_handler._handle_building_mode(event_release, end, get_viewport())

	assert_true(_bm.has_building(start), "拖拽后起点应有建筑")
	assert_true(_bm.has_building(Vector2i(2, 0)), "拖拽后中间点应有建筑")
	assert_true(_bm.has_building(end), "拖拽后终点应有建筑")

func test_remove_single_building() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	assert_true(_bm.has_building(Vector2i(5, 5)), "放置后建筑应存在")

	var event_press := _make_mouse_event(MOUSE_BUTTON_RIGHT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_RIGHT, false)

	_handler._handle_building_mode(event_press, Vector2i(5, 5), get_viewport())
	_handler._handle_building_mode(event_release, Vector2i(5, 5), get_viewport())

	assert_false(_bm.has_building(Vector2i(5, 5)), "右键单击后建筑应被删除")

func test_selection_rect_selects_buildings() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)

	SelectionManager.clear_selection()
	SelectionManager._building_manager = _bm

	var start := Vector2i(0, 0)
	var end := Vector2i(1, 1)
	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)

	_handler._handle_selection_mode(event_press, start, get_viewport())
	_handler._handle_selection_mode(event_release, end, get_viewport())

	assert_eq(SelectionManager.selected_cells.size(), 3, "框选后应选中 3 个建筑格")

func test_hover_detects_building() -> void:
	var screen_pos := Vector2(64, 64)
	var grid_pos := _screen_to_grid(screen_pos)
	_bm.place_building(grid_pos, GameConfig.container_type_id)

	watch_signals(EventBus)
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = screen_pos
	_handler._handle_mouse_motion(motion_event, get_viewport())

	assert_signal_emitted(EventBus, "building_hovered", "鼠标移动到建筑上时应发射 building_hovered 信号")

func test_paste_mode_places_buildings() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clipboard = _make_clipboard()

	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)
	_handler._handle_paste_mode(event_press, Vector2i(3, 3), get_viewport())
	assert_false(_bm.has_building(Vector2i(3, 3)), "按下左键时应仅显示预览，不立即放置建筑")
	_handler._handle_paste_mode(event_release, Vector2i(3, 3), get_viewport())

	assert_true(_bm.has_building(Vector2i(3, 3)), "松开左键后 (3, 3) 应有建筑")
	assert_true(_bm.has_building(Vector2i(4, 3)), "松开左键后 (4, 3) 应有建筑")

func test_paste_mode_drag_tiles_unit_horizontally() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clipboard = _make_clipboard()

	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)
	_handler._handle_paste_mode(event_press, Vector2i(0, 0), get_viewport())
	_handler._handle_paste_mode(event_release, Vector2i(6, 0), get_viewport())

	assert_true(_bm.has_building(Vector2i(0, 0)), "锚点 (0,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(1, 0)), "锚点 (0,0) offset(1,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(2, 0)), "锚点 (2,0) 应有建筑（单元宽度=2）")
	assert_true(_bm.has_building(Vector2i(3, 0)), "锚点 (2,0) offset(1,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(4, 0)), "锚点 (4,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(5, 0)), "锚点 (4,0) offset(1,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(6, 0)), "锚点 (6,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(7, 0)), "锚点 (6,0) offset(1,0) 应有建筑")
	assert_false(_bm.has_building(Vector2i(8, 0)), "锚点 (8,0) 不应有建筑（超出范围）")
	assert_eq(SelectionManager.undo_stack.size(), 1, "一次拖拽应只产生一条撤销命令")

func test_paste_mode_drag_tiles_unit_vertically() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clipboard = _make_clipboard()

	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)
	_handler._handle_paste_mode(event_press, Vector2i(0, 0), get_viewport())
	_handler._handle_paste_mode(event_release, Vector2i(0, 4), get_viewport())

	assert_true(_bm.has_building(Vector2i(0, 0)), "锚点 (0,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(1, 0)), "锚点 (0,0) offset(1,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(0, 1)), "锚点 (0,1) 应有建筑（单元高度=1）")
	assert_true(_bm.has_building(Vector2i(1, 1)), "锚点 (0,1) offset(1,0) 应有建筑")
	assert_true(_bm.has_building(Vector2i(0, 2)), "锚点 (0,2) 应有建筑")
	assert_true(_bm.has_building(Vector2i(1, 2)), "锚点 (0,2) offset(1,0) 应有建筑")
	assert_eq(SelectionManager.undo_stack.size(), 1, "一次拖拽应只产生一条撤销命令")

func test_mouse_motion_shows_paste_preview() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clipboard = _make_clipboard()

	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "应进入粘贴模式")

	var screen_pos := Vector2(200, 200)
	var expected_anchor := _screen_to_grid(screen_pos)
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = screen_pos
	_handler._handle_mouse_motion(motion_event, get_viewport())

	assert_eq(SelectionManager.paste_anchor, expected_anchor, "粘贴锚点应更新为鼠标所在网格坐标")

func test_paste_drag_updates_anchor() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clipboard = _make_clipboard()
	SelectionManager.start_paste_mode()
	assert_true(SelectionManager.is_paste_mode, "应进入粘贴模式")

	var press_event := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	_handler._handle_paste_mode(press_event, Vector2i(5, 5), get_viewport())

	var motion_event := InputEventMouseMotion.new()
	motion_event.position = Vector2(400, 240)
	_handler._handle_mouse_motion(motion_event, get_viewport())

	var expected_anchor := _screen_to_grid(Vector2(400, 240))
	assert_eq(SelectionManager.paste_anchor, expected_anchor, "拖拽过程中粘贴锚点应持续更新到当前鼠标位置")

func test_hover_exited_signal() -> void:
	var screen_pos := Vector2(64, 64)
	var grid_pos := _screen_to_grid(screen_pos)
	_bm.place_building(grid_pos, GameConfig.container_type_id)

	watch_signals(EventBus)

	var motion_event := InputEventMouseMotion.new()
	motion_event.position = screen_pos
	_handler._handle_mouse_motion(motion_event, get_viewport())
	assert_signal_emitted(EventBus, "building_hovered", "鼠标移动到建筑上时应发射 building_hovered")

	var empty_screen_pos := Vector2(128, 128)
	var empty_grid := _screen_to_grid(empty_screen_pos)
	assert_false(_bm.has_building(empty_grid), "目标位置应无建筑，确保触发 hover_exited 逻辑")

	var motion_event2 := InputEventMouseMotion.new()
	motion_event2.position = empty_screen_pos
	_handler._handle_mouse_motion(motion_event2, get_viewport())
	assert_signal_emitted(EventBus, "building_hover_exited", "鼠标移开建筑时应发射 building_hover_exited")

func test_remove_records_type_in_undo() -> void:
	var grid_pos := Vector2i(7, 7)
	_bm.place_building(grid_pos, GameConfig.container_type_id)
	assert_true(_bm.has_building(grid_pos), "容器应放置成功")

	var event_press := _make_mouse_event(MOUSE_BUTTON_RIGHT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_RIGHT, false)

	_handler._handle_building_mode(event_press, grid_pos, get_viewport())
	_handler._handle_building_mode(event_release, grid_pos, get_viewport())

	assert_false(_bm.has_building(grid_pos), "右键后建筑应被删除")
	assert_false(SelectionManager.undo_stack.is_empty(), "撤销栈不应为空")

	var cmd: UndoCommand = SelectionManager.undo_stack.back()
	assert_eq(cmd.type, UndoCommand.Type.REMOVE, "撤销命令类型应为 REMOVE")

	for value: Variant in cmd.buildings.values():
		assert_true(value is Dictionary, "撤销命令的 buildings 值应为字典类型")
		assert_true(value.has("type"), "字典应包含 type 键")
		assert_false(value.has("capacity"), "字典不应包含 capacity 键")
		assert_false(value.has("max_capacity"), "字典不应包含 max_capacity 键")

func test_copy_selection_fills_clipboard() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clear_selection()
	SelectionManager.clipboard = {}
	SelectionManager.undo_stack.clear()

	var grid_pos := Vector2i(5, 0)
	_bm.place_building(grid_pos, GameConfig.container_type_id)
	SelectionManager.select_cell(grid_pos)

	SelectionManager.copy_selection()
	assert_false(SelectionManager.clipboard.is_empty(), "复制后剪贴板不应为空")
	assert_true(SelectionManager.clipboard.has("buildings"), "剪贴板应含 buildings 键")
	var buildings: Array = SelectionManager.clipboard["buildings"]
	assert_eq(buildings.size(), 1, "应复制了 1 个建筑")
	assert_eq(buildings[0]["type"], GameConfig.container_type_id, "剪贴板中建筑类型应为容器")
	assert_eq(buildings[0]["offset"], Vector2i(0, 0), "单建筑偏移应为 (0, 0)")
	var was_cut: bool = SelectionManager.clipboard.get("was_cut", true)
	assert_false(was_cut, "复制操作的 was_cut 应为 false")

func test_cut_selection_records_undo_and_removes_building() -> void:
	SelectionManager._building_manager = _bm
	SelectionManager.clear_selection()
	SelectionManager.clipboard = {}
	SelectionManager.undo_stack.clear()

	var grid_pos := Vector2i(5, 1)
	_bm.place_building(grid_pos, GameConfig.container_type_id)
	SelectionManager.select_cell(grid_pos)

	SelectionManager.cut_selection()
	assert_false(_bm.has_building(grid_pos), "剪切后建筑应被删除")
	assert_false(SelectionManager.undo_stack.is_empty(), "剪切后撤销栈不应为空")
	var cmd: UndoCommand = SelectionManager.undo_stack.back()
	assert_eq(cmd.type, UndoCommand.Type.CUT, "撤销命令类型应为 CUT")
	assert_true(cmd.buildings.has(grid_pos), "撤销命令应包含被剪切的格子")
	for value: Variant in cmd.buildings.values():
		assert_true(value is Dictionary, "撤销命令的 buildings 值应为字典类型")
		assert_true(value.has("type"), "字典应包含 type 键")
