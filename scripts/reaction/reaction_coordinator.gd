class_name ReactionCoordinator
extends Node

var _timer: Timer = null
var _building_manager: BuildingManager = null

var _dirty: bool = true
var _cached_networks: Array[Dictionary] = []

var _element_grid: ElementGrid = null
var _element_diffusion: ElementDiffusion = null

var _paused: bool = false

func init(building_manager: BuildingManager) -> void:
	_building_manager = building_manager

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.pause_state_changed.connect(_on_pause_state_changed)
	_timer = Timer.new()
	_timer.wait_time = GameConfig.simulation_tick_interval
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_element_grid = ElementGrid.new()
	_element_grid.building_manager_ref = _building_manager
	add_child(_element_grid)

	_element_diffusion = ElementDiffusion.new()
	add_child(_element_diffusion)

func _exit_tree() -> void:
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.disconnect(_on_building_removed)
	if EventBus.pause_state_changed.is_connected(_on_pause_state_changed):
		EventBus.pause_state_changed.disconnect(_on_pause_state_changed)

func _on_building_placed(grid_pos: Vector2i) -> void:
	_dirty = true
	_cached_networks.clear()
	# 清除放置位置的水，防止建筑建在水体上
	if _element_grid.has_fluid(grid_pos):
		_element_grid.remove_fluid(grid_pos)

func _on_building_removed(_grid_pos: Vector2i) -> void:
	_dirty = true
	_cached_networks.clear()
	# 清除所有水源标记，被移除的建筑不再能维持水源
	# 下个 tick 的 _process_emitters() 会为仍然存在的发射器重新标记
	_element_grid.clear_all_sources()

func mark_dirty() -> void:
	_dirty = true
	_cached_networks.clear()

func _on_pause_state_changed(paused: bool) -> void:
	_paused = paused

func _on_tick() -> void:
	if not _building_manager:
		return
	if _paused:
		return

	if _dirty:
		_rebuild_networks()
		_dirty = false

	_process_emitters()

	_element_diffusion.diffuse_all(_element_grid)

	_process_collectors()

func _process_emitters() -> void:
	for network: Dictionary in _cached_networks:
		for emitter: EmitterNode in network.emitters:
			if not emitter.has_type_selected():
				continue

			var target_pos: Vector2i = emitter.grid_position + emitter.output_direction
			if _element_grid.is_building_at(target_pos):
				continue

			if not EssencePool.has(emitter.essence_cost_per_tick):
				continue

			# 每次发射器运行时都消耗源质（运行成本）
			EssencePool.subtract(emitter.essence_cost_per_tick)

			# 目标格子已有流体时无需重复创建,仅重新标记为水源以维持水体
			if _element_grid.has_fluid(target_pos):
				_element_grid.mark_as_source(target_pos)
			else:
				var success: bool = _element_grid.set_fluid(target_pos, target_pos.y)
				if success:
					_element_grid.mark_as_source(target_pos)

func _process_collectors() -> void:
	for network: Dictionary in _cached_networks:
		for collector: CollectorNode in network.collectors:
			var collected: float = collector.try_collect(_element_grid)
			if collected > 0.0:
				EssencePool.add(collected)

func _rebuild_networks() -> void:
	_cached_networks.clear()

	var core: CoreNode = _building_manager.core_node
	if core == null or not is_instance_valid(core):
		return

	var visited: Dictionary[int, bool] = {}

	# 从核心的四个邻居开始 BFS
	var core_cells: Array[Vector2i] = BuildingManager.CORE_CELLS
	for cell: Vector2i in core_cells:
		for dir: Vector2i in GridCoordinate.DIR_4:
			var neighbor_pos: Vector2i = cell + dir
			var neighbor: Node = _building_manager.get_building_node(neighbor_pos)
			if neighbor == null:
				continue
			if visited.has(neighbor.get_instance_id()):
				continue
			if neighbor is PipeNode:
				visited[neighbor.get_instance_id()] = true
				var network := _bfs_network(neighbor, visited)
				if network.pipes.size() > 0 or \
				   network.emitters.size() > 0 or network.collectors.size() > 0:
					_cached_networks.append(network)
			elif neighbor is EmitterNode or neighbor is CollectorNode:
				# 直接连接到核心的发射器/收集器也加入激活网络
				var network := {"pipes": [], "emitters": [], "collectors": []}
				if neighbor is EmitterNode:
					network.emitters.append(neighbor as EmitterNode)
				else:
					network.collectors.append(neighbor as CollectorNode)
				_cached_networks.append(network)

func _bfs_network(start_node: Node, visited: Dictionary[int, bool]) -> Dictionary:
	if _building_manager == null:
		return {"pipes": [], "emitters": [], "collectors": []}

	var pipes: Array[Node] = []
	var emitters: Array[EmitterNode] = []
	var emitter_dict: Dictionary[int, bool] = {}
	var collectors: Array[CollectorNode] = []
	var collector_dict: Dictionary[int, bool] = {}

	var queue: Array[Node] = [start_node]
	var head: int = 0

	while head < queue.size():
		var node: Node = queue[head]
		head += 1

		if node is PipeNode:
			pipes.append(node)
		elif node is EmitterNode:
			if not emitter_dict.has(node.get_instance_id()):
				emitter_dict[node.get_instance_id()] = true
				emitters.append(node)
		elif node is CollectorNode:
			if not collector_dict.has(node.get_instance_id()):
				collector_dict[node.get_instance_id()] = true
				collectors.append(node)

		if not (node is PipeNode):
			continue

		var pipe_node: PipeNode = node as PipeNode
		var dirs: Array[Vector2i] = GridCoordinate.DIR_4

		for dir_idx: int in 4:
			if (pipe_node.connection_mask & (1 << dir_idx)) == 0:
				continue

			var neighbor_pos: Vector2i = node.grid_position + dirs[dir_idx]
			var neighbor: Node = _building_manager.get_building_node(neighbor_pos)
			if neighbor == null:
				continue

			if neighbor is PipeNode:
				var neighbor_pipe: PipeNode = neighbor as PipeNode
				var opposite_dir: int = dir_idx ^ 2
				if (neighbor_pipe.connection_mask & (1 << opposite_dir)) == 0:
					continue
				if not visited.has(neighbor.get_instance_id()):
					visited[neighbor.get_instance_id()] = true
					queue.append(neighbor)
			elif neighbor is EmitterNode:
				var nid: int = neighbor.get_instance_id()
				if not emitter_dict.has(nid):
					emitter_dict[nid] = true
					emitters.append(neighbor)
			elif neighbor is CollectorNode:
				var nid: int = neighbor.get_instance_id()
				if not collector_dict.has(nid):
					collector_dict[nid] = true
					collectors.append(neighbor)

	return {
		"pipes": pipes,
		"emitters": emitters,
		"collectors": collectors,
	}
