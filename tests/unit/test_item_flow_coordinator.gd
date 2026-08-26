extends GutTest

## ItemFlowCoordinator 集成测试：tick 事件经 EventBus.sim_tick_completed 发射，
## 渲染层依赖此链路。回归测试：信号曾误发到自身信号导致渲染器收不到事件。

var _bm: BuildingManager = null
var _coord: ItemFlowCoordinator = null

func before_all() -> void:
	BuildingTypeManager.register_defaults()

func before_each() -> void:
	_bm = autoqfree(BuildingManager.new())
	add_child_autoqfree(_bm)
	_coord = _bm.get_flow_coordinator()
	# 停掉后台 0.1s Timer，避免 GUT 场景树真实分帧 tick 与测试断言竞争
	_coord._timer.stop()

func test_tick_emits_events_on_event_bus() -> void:
	_bm.place_building(Vector2i(0, 0), MachineSpec.T_NUM_SOURCE)
	var received: Array = []
	var cb := func(e: Array) -> void:
		received.append(e)
	EventBus.sim_tick_completed.connect(cb)
	_coord._on_tick()
	EventBus.sim_tick_completed.disconnect(cb)
	assert_eq(received.size(), 1, "同步 tick 应发射一次事件")
	if received.size() == 1:
		var events: Array = received[0]
		assert_false(events.is_empty(), "事件数组不应为空（源头产 1 有 spawn 事件）")
		var has_spawn := false
		for e: Dictionary in events:
			if e.get("kind", "") == "spawn":
				has_spawn = true
		assert_true(has_spawn, "事件中应含 spawn")
	assert_eq(_coord.grid.count_items(), 1, "数字源应产出 1 个物品")

func test_tick_emits_framed_path_also() -> void:
	# 分帧路径：手动置 pending 并只跑 MACHINE 阶段，随后 MOVE 阶段应补发事件
	_bm.place_building(Vector2i(0, 0), MachineSpec.T_NUM_SOURCE)
	var received: Array = []
	var cb := func(e: Array) -> void:
		received.append(e)
	EventBus.sim_tick_completed.connect(cb)
	_coord._tick_pending = true
	_coord._process(0.0)  # MACHINE
	_coord._process(0.0)  # MOVE → flush
	EventBus.sim_tick_completed.disconnect(cb)
	assert_eq(received.size(), 1, "分帧路径两阶段后应发射一次事件")
	assert_eq(_coord._pending_events.size(), 0, "发射后 pending 应清空")

func test_paused_tick_no_events() -> void:
	_bm.place_building(Vector2i(0, 0), MachineSpec.T_NUM_SOURCE)
	var received: Array = []
	var cb := func(e: Array) -> void:
		received.append(e)
	EventBus.sim_tick_completed.connect(cb)
	_coord._on_pause_state_changed(true)
	_coord._on_tick()
	EventBus.sim_tick_completed.disconnect(cb)
	assert_eq(received.size(), 0, "暂停时同步 tick 不应发射事件")
	assert_true(_coord.grid.is_empty(), "暂停时不应模拟")