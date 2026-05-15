extends GutTest

var _bm: BuildingManager = null
var _coordinator: Node = null

func before_each():
	_bm = autoqfree(BuildingManager.new())
	add_child_autoqfree(_bm)
	_coordinator = _bm.get_node("FluidCoordinator")
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

func after_each():
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

func _refresh_all_pipes() -> void:
	for grid_pos in _bm.buildings.keys():
		var node := _bm.get_building_node(grid_pos)
		if node is PipeNode:
			node.refresh_connections(_bm.is_fluid_building_at)

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
	var source = _bm.get_node("Building_0_0")
	source.remaining_output = 0
	_coordinator._on_tick()
	assert_eq(source.remaining_output, source.output_per_tick, "水源每 tick 应重置 remaining_output")


func test_source_to_container_via_pipe():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container = _bm.get_node("Building_2_0")
	var source = _bm.get_node("Building_0_0")
	assert_eq(container.capacity, 0, "初始容器应为空")

	_coordinator._on_tick()

	assert_true(container.capacity > 0, "水源应通过管道向容器输水")
	assert_eq(container.capacity, source.output_per_tick, "水源每 tick 产出应全部分配给容器")


func test_non_adjacent_container_receives_no_water():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 2), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 3), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_a = _bm.get_building_node(Vector2i(0, 2))
	var container_b = _bm.get_building_node(Vector2i(0, 3))

	_coordinator._on_tick()

	assert_eq(container_a.capacity, 30, "水源通过管道应只给直接相邻的容器A分配全部水量")
	assert_eq(container_b.capacity, 0, "容器B不直接相邻水源/管道，不应接收水")


func test_only_directly_adjacent_containers_receive_water():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 2), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 2), GameConfig.container_type_id)
	_bm.place_building(Vector2i(-1, 2), GameConfig.container_type_id)
	_refresh_all_pipes()

	var containers = []
	for x in [-1, 0, 1]:
		containers.append(_bm.get_node("Building_%d_2" % x))

	var source = _bm.get_node("Building_0_0")
	_coordinator._on_tick()

	assert_eq(containers[1].capacity, 30, "只有直接相邻水源/管道的容器2应接收全部水量")
	assert_eq(containers[0].capacity, 0, "不直接相邻水源/管道的容器不应接收水")
	assert_eq(containers[2].capacity, 0, "不直接相邻水源/管道的容器不应接收水")


func test_output_per_tick_constraint():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var source = _bm.get_node("Building_0_0")
	source.output_per_tick = 0
	var container = _bm.get_node("Building_2_0")

	_coordinator._on_tick()

	assert_eq(container.capacity, 0, "output_per_tick=0 时不应输水")


func test_flow_stops_when_containers_full():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var source = _bm.get_node("Building_0_0")
	var container = _bm.get_node("Building_2_0")
	container.capacity = container.max_capacity

	_coordinator._on_tick()

	assert_eq(container.capacity, container.max_capacity, "满容器不应再接收水")
	assert_eq(source.remaining_output, source.output_per_tick, "水未分配时水源 remaining_output 应不变")


func test_fluid_updated_emitted_when_flow():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_emitted(EventBus, "fluid_updated", "有流量时应发射 fluid_updated 信号")


func test_fluid_updated_not_emitted_when_no_flow():
	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_not_emitted(EventBus, "fluid_updated", "无流量时不应发射 fluid_updated 信号")


func test_sync_building_data_after_tick():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_data = _bm.buildings[Vector2i(2, 0)]
	var source = _bm.get_node("Building_0_0")
	_coordinator._on_tick()
	assert_eq(container_data.capacity, source.output_per_tick, "tick 后 BuildingManager 的 data.capacity 应与容器同步")


func test_pipe_network_state_active():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipe = _bm.get_node("Building_1_0")
	_coordinator._on_tick()
	assert_eq(pipe.network_state, 1, "有水源且容器未满时 network_state 应为 1")


func test_pipe_network_state_full():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipe = _bm.get_node("Building_1_0")
	var container = _bm.get_node("Building_2_0")
	container.capacity = container.max_capacity

	_coordinator._on_tick()

	assert_eq(pipe.network_state, 2, "有水源且所有容器已满时 network_state 应为 2")


func test_pipe_network_state_no_source():
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipe = _bm.get_node("Building_1_0")
	_coordinator._on_tick()
	assert_eq(pipe.network_state, 0, "无水源时 network_state 应为 0")


func test_multi_hop_pipe_network():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(3, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(4, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container = _bm.get_node("Building_4_0")
	var source = _bm.get_node("Building_0_0")

	_coordinator._on_tick()
	assert_true(container.capacity > 0, "水源应通过多段管道向容器输水")
	assert_eq(container.capacity, source.output_per_tick, "多段管道传输后水量不应丢失")


func test_disconnected_networks():
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)

	_bm.place_building(Vector2i(5, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(6, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(7, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_a = _bm.get_node("Building_2_0")
	var container_b = _bm.get_node("Building_7_0")
	var source_a = _bm.get_node("Building_0_0")
	var source_b = _bm.get_node("Building_5_0")

	_coordinator._on_tick()

	assert_eq(container_a.capacity, source_a.output_per_tick, "网络 A 应正常分配产出")
	assert_eq(container_b.capacity, source_b.output_per_tick, "网络 B 应正常分配产出")


func test_container_to_container_no_direct_transfer():
	# 水源 → 容器 → 容器：容器不能作为中继节点
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_a = _bm.get_node("Building_1_0")
	var container_b = _bm.get_node("Building_2_0")
	var source = _bm.get_node("Building_0_0")

	_coordinator._on_tick()

	assert_eq(container_a.capacity, source.output_per_tick, "水源直接相邻的容器应接收水")
	assert_eq(container_b.capacity, 0, "不能通过容器向另一个容器传输水")


func test_container_pipe_continues_to_downstream_container():
	# 水源 → 容器 → 管道 → 容器：容器不阻断传播，管道可从容器继续传输
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(3, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_first = _bm.get_node("Building_1_0")
	var container_second = _bm.get_node("Building_3_0")
	var source = _bm.get_node("Building_0_0")

	_coordinator._on_tick()

	assert_eq(container_first.capacity, source.output_per_tick / 2, "水源直接相邻的容器应接收水")
	assert_eq(container_second.capacity, source.output_per_tick / 2, "管道可从容器继续传输，下游容器应接收均分的水")


func test_full_container_does_not_block_downstream_pipe():
	# 水源 → 管道 → 容器(满) → 管道：满容器不应阻断 BFS，下游管道应被发现
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(3, 0), GameConfig.pipe_type_id)
	_refresh_all_pipes()

	var container = _bm.get_node("Building_2_0")
	var pipe_downstream = _bm.get_node("Building_3_0")
	container.capacity = container.max_capacity

	_coordinator._on_tick()

	assert_eq(pipe_downstream.network_state, 2, "满容器下游管道应被 BFS 发现，state=2（已满载）而非 0（未连通）")


func test_full_container_then_downstream_empty_container():
	# 水源 → 管道 → 容器(满) → 管道 → 容器(空)：满容器不阻断传播，下游空容器应接收水
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(3, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(4, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_first = _bm.get_node("Building_2_0")
	var container_second = _bm.get_node("Building_4_0")
	var source = _bm.get_node("Building_0_0")
	container_first.capacity = container_first.max_capacity

	_coordinator._on_tick()

	assert_eq(container_first.capacity, container_first.max_capacity, "满容器不应再接收水")
	assert_eq(container_second.capacity, source.output_per_tick, "满容器不应阻断传播，下游空容器应接收全部水量")
