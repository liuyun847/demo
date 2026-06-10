extends GutTest

# 验证 EventBus 所有信号可连接和发射，不抛出异常
# 每个信号测试：连接 lambda → 发射 → 验证触发

func test_building_placed_signal() -> void:
	var triggered := [false]
	EventBus.building_placed.connect(func(_p: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.building_placed.emit(Vector2i(1, 2))
	assert_true(triggered[0], "building_placed 信号应触发，参数 Vector2i(1, 2)")

func test_building_removed_signal() -> void:
	var triggered := [false]
	EventBus.building_removed.connect(func(_p: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.building_removed.emit(Vector2i(3, 4))
	assert_true(triggered[0], "building_removed 信号应触发，参数 Vector2i(3, 4)")

func test_buildings_loaded_signal() -> void:
	var triggered := [false]
	EventBus.buildings_loaded.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.buildings_loaded.emit()
	assert_true(triggered[0], "buildings_loaded 信号应触发")

func test_keybind_changed_signal() -> void:
	var triggered := [false]
	EventBus.keybind_changed.connect(func(_a: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.keybind_changed.emit("move_left")
	assert_true(triggered[0], "keybind_changed 信号应触发")

func test_start_game_requested_signal() -> void:
	var triggered := [false]
	EventBus.start_game_requested.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.start_game_requested.emit()
	assert_true(triggered[0], "start_game_requested 信号应触发")

func test_show_start_menu_requested_signal() -> void:
	var triggered := [false]
	EventBus.show_start_menu_requested.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.show_start_menu_requested.emit()
	assert_true(triggered[0], "show_start_menu_requested 信号应触发")

func test_show_settings_requested_signal() -> void:
	var triggered := [false]
	EventBus.show_settings_requested.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.show_settings_requested.emit()
	assert_true(triggered[0], "show_settings_requested 信号应触发")

func test_game_settings_changed_signal() -> void:
	var triggered := [false]
	EventBus.game_settings_changed.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.game_settings_changed.emit()
	assert_true(triggered[0], "game_settings_changed 信号应触发")

func test_selection_changed_signal() -> void:
	var triggered := [false]
	EventBus.selection_changed.connect(func(_c: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.selection_changed.emit([Vector2i(0, 0), Vector2i(1, 1)])
	assert_true(triggered[0], "selection_changed 信号应触发")

func test_paste_mode_changed_signal() -> void:
	var triggered := [false]
	EventBus.paste_mode_changed.connect(func(_a: bool) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.paste_mode_changed.emit(true)
	assert_true(triggered[0], "paste_mode_changed 信号应触发（参数 true）")

	var triggered_false := [false]
	EventBus.paste_mode_changed.connect(func(_a: bool) -> void: triggered_false[0] = true, CONNECT_ONE_SHOT)
	EventBus.paste_mode_changed.emit(false)
	assert_true(triggered_false[0], "paste_mode_changed 信号应触发（参数 false）")

func test_camera_changed_signal() -> void:
	var triggered := [false]
	EventBus.camera_changed.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.camera_changed.emit()
	assert_true(triggered[0], "camera_changed 信号应触发")

func test_building_hovered_signal() -> void:
	var triggered := [false]
	EventBus.building_hovered.connect(func(_p: Variant, _n: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.building_hovered.emit(Vector2i(0, 0), null)
	assert_true(triggered[0], "building_hovered 信号应触发")

func test_building_hover_exited_signal() -> void:
	var triggered := [false]
	EventBus.building_hover_exited.connect(func(_p: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.building_hover_exited.emit(Vector2i(0, 0))
	assert_true(triggered[0], "building_hover_exited 信号应触发")

func test_element_spawned_signal() -> void:
	var triggered := [false]
	EventBus.element_spawned.connect(func(_p: Variant, _t: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.element_spawned.emit(Vector2i(5, 5), "water")
	assert_true(triggered[0], "element_spawned 信号应触发")

func test_element_removed_signal() -> void:
	var triggered := [false]
	EventBus.element_removed.connect(func(_p: Variant, _t: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.element_removed.emit(Vector2i(5, 5), "water")
	assert_true(triggered[0], "element_removed 信号应触发")

func test_essence_threshold_reached_signal() -> void:
	var triggered := [false]
	EventBus.essence_threshold_reached.connect(func(_t: Variant, _u: Variant) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.essence_threshold_reached.emit(100.0, {"type_03": "pipe"})
	assert_true(triggered[0], "essence_threshold_reached 信号应触发")

func test_pause_state_changed_signal() -> void:
	var triggered := [false]
	EventBus.pause_state_changed.connect(func(_p: bool) -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.pause_state_changed.emit(true)
	assert_true(triggered[0], "pause_state_changed 信号应触发（参数 true）")

func test_emitter_type_panel_opened_signal() -> void:
	var triggered := [false]
	EventBus.emitter_type_panel_opened.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.emitter_type_panel_opened.emit()
	assert_true(triggered[0], "emitter_type_panel_opened 信号应触发")

func test_emitter_type_panel_closed_signal() -> void:
	var triggered := [false]
	EventBus.emitter_type_panel_closed.connect(func() -> void: triggered[0] = true, CONNECT_ONE_SHOT)
	EventBus.emitter_type_panel_closed.emit()
	assert_true(triggered[0], "emitter_type_panel_closed 信号应触发")

func test_multiple_connections_all_fire() -> void:
	var count := [0]
	EventBus.camera_changed.connect(func() -> void: count[0] += 1)
	EventBus.camera_changed.connect(func() -> void: count[0] += 1)
	EventBus.camera_changed.emit()
	assert_eq(count[0], 2, "同一信号的多连接应全部触发")