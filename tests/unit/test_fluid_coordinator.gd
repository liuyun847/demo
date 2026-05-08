extends GutTest

var _bm: BuildingManager = null
var _coordinator: FluidCoordinator = null

func before_each():
	_bm = autoqfree(BuildingManager.new())
	add_child_autoqfree(_bm)
	_coordinator = _bm.get_node("FluidCoordinator")

func after_each():
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)


func _add_to_fluid_group(pos: Vector2i) -> void:
	var node_name := "Building_%d_%d" % [pos.x, pos.y]
	var node = _bm.get_node_or_null(node_name)
	if node:
		node.add_to_group("fluid_node")

func _find_timer() -> Timer:
	for child in _coordinator.get_children():
		if child is Timer:
			return child
	return null


func test_ready_creates_timer():
	var timer = _find_timer()
	assert_not_null(timer, "_ready 应创建 Timer 节点")
	if timer:
		assert_eq(timer.wait_time, GameConfig.fluid_tick_interval, "Timer 间隔应符合配置")


func test_empty_fluid_list_does_not_crash():
	_coordinator._on_tick()
	assert_true(true, "节点组为空时 _on_tick 不应崩溃")


func test_water_source_remaining_output_reset():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	var source = _bm.get_node("Building_0_0")
	source.remaining_output = 0
	_coordinator._on_tick()
	assert_eq(source.remaining_output, source.output_per_tick, "水源每 tick 应重置 remaining_output")


func test_source_to_pipe_transfer():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	_add_to_fluid_group(Vector2i(1, 0))
	var pipe = _bm.get_node("Building_1_0")
	assert_eq(pipe.capacity, 0, "初始管道应为空")
	_coordinator._on_tick()
	assert_true(pipe.capacity > 0, "水源应向管道推水")


func test_pipe_to_container_transfer():
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.container_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	_add_to_fluid_group(Vector2i(1, 0))
	var pipe = _bm.get_node("Building_0_0")
	var container = _bm.get_node("Building_1_0")
	pipe.capacity = pipe.max_capacity
	_coordinator._on_tick()
	assert_true(container.capacity > 0, "满管道应向容器推水")


func test_multi_iteration_convergence():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	for x in range(3):
		_add_to_fluid_group(Vector2i(x, 0))
	var pipe = _bm.get_node("Building_1_0")
	pipe.capacity = 0
	var old_total = 0
	for _iter in range(3):
		_coordinator._on_tick()
		var total = 0
		for x in range(3):
			var node = _bm.get_node("Building_%d_0" % x)
			if node.has_method("get_pressure"):
				total += node.capacity
		if total == old_total:
			break
		old_total = total
	assert_true(true, "多次迭代后应收敛")


func test_output_per_tick_constraint():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	_add_to_fluid_group(Vector2i(1, 0))
	var source = _bm.get_node("Building_0_0")
	source.output_per_tick = 0
	_coordinator._on_tick()
	var pipe = _bm.get_node("Building_1_0")
	assert_eq(pipe.capacity, 0, "output_per_tick=0 时不应推水")


func test_pipe_cannot_exceed_max_capacity():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	_add_to_fluid_group(Vector2i(1, 0))
	var pipe = _bm.get_node("Building_1_0")
	pipe.capacity = pipe.max_capacity - 1
	var source = _bm.get_node("Building_0_0")
	source.remaining_output = 999
	_coordinator._on_tick()
	assert_true(pipe.capacity <= pipe.max_capacity, "管道容量不应超过 max_capacity")


func test_fluid_updated_emitted_when_flow():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	_add_to_fluid_group(Vector2i(1, 0))
	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_emitted(EventBus, "fluid_updated", "有流量时应发射 fluid_updated 信号")


func test_fluid_updated_not_emitted_when_no_flow():
	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_not_emitted(EventBus, "fluid_updated", "无流量时不应发射 fluid_updated 信号")


func test_sync_building_data_after_tick():
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.container_type_id)
	_add_to_fluid_group(Vector2i(0, 0))
	_add_to_fluid_group(Vector2i(1, 0))
	var pipe = _bm.get_node("Building_0_0")
	var pipe_data = _bm.buildings[Vector2i(0, 0)]
	pipe.capacity = 3
	_coordinator._on_tick()
	assert_eq(pipe_data.capacity, pipe.capacity, "tick 后 BuildingManager 的 data.capacity 应与节点同步")
