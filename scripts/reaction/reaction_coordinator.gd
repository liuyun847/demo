class_name ReactionCoordinator
extends Node

var _timer: Timer = null
var _building_manager: BuildingManager = null

var _dirty: bool = true
var _cached_networks: Array[Dictionary] = []

var _element_grid: ElementGrid = null
var _element_diffusion: ElementDiffusion = null

func init(building_manager: BuildingManager) -> void:
	_building_manager = building_manager

func _ready() -> void:
	EventBus.building_placed.connect(_on_topology_changed)
	EventBus.building_removed.connect(_on_topology_changed)
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
	if EventBus.building_placed.is_connected(_on_topology_changed):
		EventBus.building_placed.disconnect(_on_topology_changed)
	if EventBus.building_removed.is_connected(_on_topology_changed):
		EventBus.building_removed.disconnect(_on_topology_changed)

func _on_topology_changed(_grid_pos: Vector2i) -> void:
	_dirty = true
	_cached_networks.clear()

func mark_dirty() -> void:
	_dirty = true
	_cached_networks.clear()

func _on_tick() -> void:
	if not _building_manager:
		return
	var all_pipes: Array[PipeNode] = _building_manager.network_pipes

	if _dirty:
		_rebuild_networks(all_pipes)
		_dirty = false

	_process_emitters()

	_element_diffusion.diffuse_all(_element_grid, GameConfig.diffusion_steps_per_tick)

	_process_collectors()

func _process_emitters() -> void:
	var total_cost: float = 0.0
	var ready_emitters: Array[EmitterNode] = []

	for network: Dictionary in _cached_networks:
		for emitter: EmitterNode in network.emitters:
			if not emitter.has_type_selected():
				continue

			if emitter.is_blocked():
				emitter.try_output(_element_grid)
				continue

			var target_pos: Vector2i = emitter.grid_position + emitter.output_direction
			if not _element_grid.is_position_available(target_pos):
				emitter.try_output(_element_grid)
				continue

			ready_emitters.append(emitter)
			total_cost += emitter.essence_cost_per_tick

	if ready_emitters.is_empty() or total_cost <= 0.0:
		return

	var available: float = EssencePool.essence
	if available <= 0.0:
		return

	var ratio: float = minf(1.0, available / total_cost)

	for emitter: EmitterNode in ready_emitters:
		var actual_cost: float = emitter.essence_cost_per_tick * ratio
		EssencePool.subtract(actual_cost)
		emitter.try_output(_element_grid)

func _process_collectors() -> void:
	var collector_dict: Dictionary[int, bool] = {}
	for network: Dictionary in _cached_networks:
		for collector: CollectorNode in network.collectors:
			var cid: int = collector.get_instance_id()
			if collector_dict.has(cid):
				continue
			collector_dict[cid] = true
			var collected: float = collector.try_collect(_element_grid)
			if collected > 0.0:
				EssencePool.add(collected)

func _rebuild_networks(pipes: Array[PipeNode]) -> void:
	_cached_networks.clear()

	if pipes.is_empty():
		return

	var visited: Dictionary[int, bool] = {}

	for i in pipes.size():
		var node: Node = pipes[i]
		if visited.has(node.get_instance_id()):
			continue
		var network := _bfs_network(node, visited)
		if network.pipes.size() > 0 or network.containers.size() > 0 or \
		   network.emitters.size() > 0 or network.collectors.size() > 0:
			_cached_networks.append(network)


func _bfs_network(start_node: Node, visited: Dictionary[int, bool]) -> Dictionary:
	if _building_manager == null:
		return {"pipes": [], "containers": [], "emitters": [], "collectors": []}

	var pipes: Array[Node] = []
	var containers: Array[Node] = []
	var container_dict: Dictionary[int, bool] = {}
	var emitters: Array[EmitterNode] = []
	var emitter_dict: Dictionary[int, bool] = {}
	var collectors: Array[CollectorNode] = []
	var collector_dict: Dictionary[int, bool] = {}

	var queue: Array[Node] = [start_node]
	var head: int = 0
	visited[start_node.get_instance_id()] = true

	while head < queue.size():
		var node: Node = queue[head]
		head += 1

		if node is PipeNode:
			pipes.append(node)
		elif node is ContainerNode:
			if not container_dict.has(node.get_instance_id()):
				container_dict[node.get_instance_id()] = true
				containers.append(node)

		if not (node is PipeNode or node is ContainerNode):
			continue

		var dirs: Array[Vector2i] = GridCoordinate.DIR_4

		for dir_idx: int in 4:
			if node is PipeNode:
				var pipe_node: PipeNode = node as PipeNode
				if (pipe_node.connection_mask & (1 << dir_idx)) == 0:
					continue

			var neighbor_pos: Vector2i = node.grid_position + dirs[dir_idx]
			var neighbor: Node = _building_manager.get_building_node(neighbor_pos)
			if neighbor == null:
				continue

			if node is ContainerNode and neighbor is ContainerNode:
				continue

			if neighbor is PipeNode:
				var neighbor_pipe: PipeNode = neighbor as PipeNode
				var opposite_dir: int = dir_idx ^ 2
				if (neighbor_pipe.connection_mask & (1 << opposite_dir)) == 0:
					continue
				if not visited.has(neighbor.get_instance_id()):
					visited[neighbor.get_instance_id()] = true
					queue.append(neighbor)
			elif neighbor is ContainerNode:
				if not container_dict.has(neighbor.get_instance_id()):
					container_dict[neighbor.get_instance_id()] = true
					containers.append(neighbor)
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
		"containers": containers,
		"emitters": emitters,
		"collectors": collectors,
	}