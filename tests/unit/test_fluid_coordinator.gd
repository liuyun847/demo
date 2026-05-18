extends GutTest

var _bm: BuildingManager = null
var _coordinator: Node = null

func before_each() -> void:
	_bm = autoqfree(BuildingManager.new())
	var pr = preload("res://scripts/building/pipe_render_system.gd").new()
	pr.name = "PipeRenderSystem"
	_bm.add_child(pr)
	add_child_autoqfree(_bm)
	_coordinator = _bm.get_node("FluidCoordinator")
	for conn in EventBus.fluid_updated.get_connections():
		EventBus.fluid_updated.disconnect(conn.callable)

func after_each() -> void:
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


func test_ready_creates_timer() -> void:
	var timer = _find_timer()
	assert_not_null(timer, "_ready 应创建 Timer 节点")
	if timer:
		assert_eq(timer.wait_time, GameConfig.fluid_tick_interval, "Timer 间隔应符合配置")


func test_empty_fluid_list_does_not_crash() -> void:
	_coordinator._on_tick()
	assert_true(true, "节点组为空时 _on_tick 不应崩溃")


func test_water_source_remaining_output_reset() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	var source = _bm.get_node("Building_0_0")
	source._remaining_output = 0
	_coordinator._on_tick()
	assert_eq(source._remaining_output, source.output_per_tick, "水源每 tick 应重置 remaining_output")


func test_source_to_container_via_pipe() -> void:
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


func test_container_to_container_no_relay() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 2), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 3), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_a = _bm.get_building_node(Vector2i(0, 2))
	var container_b = _bm.get_building_node(Vector2i(0, 3))

	_coordinator._on_tick()

	assert_eq(container_a.capacity, 30, "水源通过管道应只给直接相邻的容器A分配全部水量")
	assert_eq(container_b.capacity, 0, "容器不能作为中继向另一个容器传输水")


func test_only_directly_adjacent_containers_receive_water() -> void:
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


func test_output_per_tick_constraint() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var source = _bm.get_node("Building_0_0")
	source.output_per_tick = 0
	var container = _bm.get_node("Building_2_0")

	_coordinator._on_tick()

	assert_eq(container.capacity, 0, "output_per_tick=0 时不应输水")


func test_flow_stops_when_containers_full() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var source = _bm.get_node("Building_0_0")
	var container = _bm.get_node("Building_2_0")
	container.capacity = container.max_capacity

	_coordinator._on_tick()

	assert_eq(container.capacity, container.max_capacity, "满容器不应再接收水")
	assert_eq(source._remaining_output, source.output_per_tick, "水未分配时水源 remaining_output 应不变")


func test_fluid_updated_emitted_when_flow() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_emitted(EventBus, "fluid_updated", "有流量时应发射 fluid_updated 信号")


func test_fluid_updated_not_emitted_when_no_flow() -> void:
	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_not_emitted(EventBus, "fluid_updated", "无流量时不应发射 fluid_updated 信号")


func test_sync_building_data_after_tick() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var container_data = _bm.buildings[Vector2i(2, 0)]
	var source = _bm.get_node("Building_0_0")
	_coordinator._on_tick()
	assert_eq(container_data.capacity, source.output_per_tick, "tick 后 BuildingManager 的 data.capacity 应与容器同步")


func test_pipe_network_state_active() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipe = _bm.get_node("Building_1_0")
	_coordinator._on_tick()
	assert_eq(pipe.network_state, 1, "有水源且容器未满时 network_state 应为 1")


func test_pipe_network_state_full() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipe = _bm.get_node("Building_1_0")
	var container = _bm.get_node("Building_2_0")
	container.capacity = container.max_capacity

	_coordinator._on_tick()

	assert_eq(pipe.network_state, 2, "有水源且所有容器已满时 network_state 应为 2")


func test_pipe_network_state_no_source() -> void:
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipe = _bm.get_node("Building_1_0")
	_coordinator._on_tick()
	assert_eq(pipe.network_state, 0, "无水源时 network_state 应为 0")


func test_multi_hop_pipe_network() -> void:
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


func test_disconnected_networks() -> void:
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


func test_container_to_container_no_direct_transfer() -> void:
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


func test_container_pipe_continues_to_downstream_container() -> void:
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


func test_full_container_does_not_block_downstream_pipe() -> void:
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


func test_full_container_then_downstream_empty_container() -> void:
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


func test_bfs_network_isolated_pipe() -> void:
	_bm.place_building(Vector2i(3, 3), GameConfig.pipe_type_id)
	_refresh_all_pipes()
	_coordinator.mark_dirty()
	assert_true(_coordinator._dirty, "mark_dirty 应设置 _dirty=true")

	var pipes: Array[PipeNode] = _bm.fluid_pipes
	var empty_sources: Array[WaterSourceNode] = []
	_coordinator._rebuild_networks(pipes, empty_sources)
	assert_eq(_coordinator._cached_networks.size(), 1, "孤立管道应形成一个网络")
	if _coordinator._cached_networks.size() > 0:
		var net = _coordinator._cached_networks[0]
		assert_eq(net.pipes.size(), 1, "网络应有 1 个管道")
		assert_eq(net.sources.size(), 0, "网络应无水源")
		assert_eq(net.containers.size(), 0, "网络应无容器")


func test_bfs_network_source_pipe_container() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipes: Array = _bm.fluid_pipes
	var sources: Array = _bm.fluid_sources
	_coordinator._rebuild_networks(pipes, sources)
	assert_eq(_coordinator._cached_networks.size(), 1, "水源-管道-容器应形成一个网络")
	if _coordinator._cached_networks.size() > 0:
		var net = _coordinator._cached_networks[0]
		assert_eq(net.sources.size(), 1, "网络应有 1 个水源")
		assert_eq(net.pipes.size(), 1, "网络应有 1 个管道")
		assert_eq(net.containers.size(), 1, "网络应有 1 个容器")


func test_bfs_network_branched() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 1), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipes: Array = _bm.fluid_pipes
	var sources: Array = _bm.fluid_sources
	_coordinator._rebuild_networks(pipes, sources)
	assert_eq(_coordinator._cached_networks.size(), 1, "分叉网络应为同一个网络")
	if _coordinator._cached_networks.size() > 0:
		var net = _coordinator._cached_networks[0]
		assert_eq(net.sources.size(), 1, "网络应有 1 个水源")
		assert_eq(net.containers.size(), 2, "分叉后应有 2 个容器")


func test_bfs_network_disconnected() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(10, 10), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(11, 10), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipes: Array = _bm.fluid_pipes
	var sources: Array = _bm.fluid_sources
	_coordinator._rebuild_networks(pipes, sources)
	assert_eq(_coordinator._cached_networks.size(), 2, "两套独立网络应形成 2 个网络")


func test_bfs_network_container_adjacent_to_container() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 2), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipes: Array[PipeNode] = _bm.fluid_pipes
	var sources: Array[WaterSourceNode] = _bm.fluid_sources
	_coordinator._rebuild_networks(pipes, sources)
	assert_eq(_coordinator._cached_networks.size(), 1, "水源和一个容器应形成一个网络")
	if _coordinator._cached_networks.size() > 0:
		var net = _coordinator._cached_networks[0]
		assert_eq(net.sources.size(), 1, "网络应有 1 个水源")
		assert_eq(net.containers.size(), 1, "只有一个容器（容器不能通过另一个容器传播）")


func test_bfs_network_multi_source() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.water_source_type_id)
	_bm.place_building(Vector2i(1, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 1), GameConfig.container_type_id)
	_refresh_all_pipes()

	var pipes: Array = _bm.fluid_pipes
	var sources: Array = _bm.fluid_sources
	_coordinator._rebuild_networks(pipes, sources)
	assert_eq(_coordinator._cached_networks.size(), 1, "多个水源在同一网络")
	if _coordinator._cached_networks.size() > 0:
		var net = _coordinator._cached_networks[0]
		assert_eq(net.sources.size(), 2, "网络应有 2 个水源")


func test_on_topology_changed_marks_dirty() -> void:
	_coordinator._dirty = false
	var dummy: Array[Dictionary] = [{"sources": [], "pipes": [], "containers": []}]
	_coordinator._cached_networks = dummy
	_coordinator._on_topology_changed(Vector2i(0, 0))
	assert_true(_coordinator._dirty, "_on_topology_changed 应设置 _dirty=true")
	assert_true(_coordinator._cached_networks.is_empty(), "_on_topology_changed 应清空缓存")


func test_mark_dirty() -> void:
	_coordinator._dirty = false
	var dummy: Array[Dictionary] = [{"sources": [], "pipes": [], "containers": []}]
	_coordinator._cached_networks = dummy
	_coordinator.mark_dirty()
	assert_true(_coordinator._dirty, "mark_dirty 应设置 _dirty=true")
	assert_true(_coordinator._cached_networks.is_empty(), "mark_dirty 应清空缓存")


func test_on_tick_empty_world() -> void:
	watch_signals(EventBus)
	_coordinator._on_tick()
	assert_signal_not_emitted(EventBus, "fluid_updated", "无建筑时不应发射 fluid_updated 信号")
