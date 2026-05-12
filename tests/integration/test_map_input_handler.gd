extends GutTest

var _bm: Node2D = null
var _handler: Node = null
var _bar: InventoryBar = null
var _camera: Camera2D = null

func before_each():
	load("res://scripts/building/fluid_node_base.gd")
	load("res://scripts/building/container_node.gd")
	load("res://scripts/building/pipe_node.gd")
	load("res://scripts/building/water_source_node.gd")
	load("res://scripts/resources/building_data.gd")
	load("res://scripts/resources/undo_command.gd")

	_camera = autoqfree(Camera2D.new())
	_camera.enabled = true
	add_child_autoqfree(_camera)

	var bm_script = load("res://scripts/building/building_manager.gd")
	_bm = autoqfree(bm_script.new())
	add_child_autoqfree(_bm)

	_bar = autoqfree(load("res://scripts/ui/inventory_bar.gd").new())
	_bar.name = "InventoryBar"
	add_child_autoqfree(_bar)

	var handler_script = load("res://scripts/grid/map_input_handler.gd")
	_handler = autoqfree(handler_script.new())
	_handler.building_manager = _bm
	_handler.inventory_bar = _bar
	add_child_autoqfree(_handler)

	SelectionManager.clear_selection()
	SelectionManager.clipboard = {}

func after_each():
	SelectionManager.clipboard = {}
	SelectionManager._building_manager = null

func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var view_size := get_viewport().get_visible_rect().size
	var center := view_size / 2.0
	var offset := (screen_pos - center) / _camera.zoom
	var world_pos := offset + _camera.global_position
	return Vector2i(
		floor(world_pos.x / GameConfig.cell_size),
		floor(world_pos.y / GameConfig.cell_size)
	)

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

func test_place_single_building():
	_bar.select_slot(0)
	var building_type = _bar.get_current_building_type()
	assert_ne(building_type, "default", "选中槽位后应返回非 default 的类型")

	var grid_pos := Vector2i(10, 10)
	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_LEFT, false)

	_handler._handle_building_mode(event_press, grid_pos, get_viewport())
	_handler._handle_building_mode(event_release, grid_pos, get_viewport())

	assert_true(_bm.has_building(grid_pos), "左键单击后建筑应放置在 (10, 10)")
	assert_eq(_bm.buildings[grid_pos].building_type, building_type, "建筑类型应与选中槽位一致")

func test_place_building_line_drag():
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

func test_remove_single_building():
	_bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	assert_true(_bm.has_building(Vector2i(5, 5)), "放置后建筑应存在")

	var event_press := _make_mouse_event(MOUSE_BUTTON_RIGHT, true)
	var event_release := _make_mouse_event(MOUSE_BUTTON_RIGHT, false)

	_handler._handle_building_mode(event_press, Vector2i(5, 5), get_viewport())
	_handler._handle_building_mode(event_release, Vector2i(5, 5), get_viewport())

	assert_false(_bm.has_building(Vector2i(5, 5)), "右键单击后建筑应被删除")

func test_selection_rect_selects_buildings():
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

func test_hover_detects_building():
	var screen_pos := Vector2(64, 64)
	var grid_pos := _screen_to_grid(screen_pos)
	_bm.place_building(grid_pos, GameConfig.container_type_id)

	watch_signals(EventBus)
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = screen_pos
	_handler._handle_mouse_motion(motion_event, get_viewport())

	assert_signal_emitted(EventBus, "building_hovered", "鼠标移动到建筑上时应发射 building_hovered 信号")

func test_paste_mode_places_buildings():
	SelectionManager._building_manager = _bm
	SelectionManager.clipboard = _make_clipboard()

	var event_press := _make_mouse_event(MOUSE_BUTTON_LEFT, true)
	_handler._handle_paste_mode(event_press, Vector2i(3, 3), get_viewport())

	assert_true(_bm.has_building(Vector2i(3, 3)), "粘贴后 (3, 3) 应有建筑")
	assert_true(_bm.has_building(Vector2i(4, 3)), "粘贴后 (4, 3) 应有建筑")

func test_mouse_motion_shows_paste_preview():
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
