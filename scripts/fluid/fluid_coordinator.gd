class_name FluidCoordinator
extends Node

var _timer: Timer = null
var _building_manager: BuildingManager = null

var _dirty: bool = true
var _cached_networks: Array[Dictionary] = []

func _ready() -> void:
	_building_manager = get_parent() as BuildingManager
	EventBus.building_placed.connect(_on_topology_changed)
	EventBus.building_removed.connect(_on_topology_changed)
	_timer = Timer.new()
	_timer.wait_time = GameConfig.fluid_tick_interval
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

func _exit_tree() -> void:
	if EventBus.building_placed.is_connected(_on_topology_changed):
		EventBus.building_placed.disconnect(_on_topology_changed)
	if EventBus.building_removed.is_connected(_on_topology_changed):
		EventBus.building_removed.disconnect(_on_topology_changed)

func _on_topology_changed(_grid_pos: Vector2i) -> void:
	_dirty = true

func _on_tick() -> void:
	if not _building_manager:
		return
	var all_pipes: Array[PipeNode] = _building_manager.fluid_pipes
	var all_sources: Array[WaterSourceNode] = _building_manager.fluid_sources

	if all_pipes.is_empty() and all_sources.is_empty():
		_cached_networks.clear()
		_dirty = false
		return

	if _dirty:
		_rebuild_networks(all_pipes, all_sources)
		_dirty = false

	for src in all_sources:
		src.reset_output()

	var has_flow := false
	var pipes_in_network: Dictionary[int, bool] = {}

	for network: Dictionary in _cached_networks:
		has_flow = _process_network(network) or has_flow
		for pipe in network.pipes:
			pipes_in_network[pipe.get_instance_id()] = true

	for pipe in all_pipes:
		if not pipes_in_network.has(pipe.get_instance_id()):
			pipe.network_state = 0

	if has_flow:
		EventBus.fluid_updated.emit()

func _rebuild_networks(pipes: Array[PipeNode], sources: Array[WaterSourceNode]) -> void:
	_cached_networks.clear()

	var node_count := pipes.size() + sources.size()
	if node_count == 0:
		return

	var visited: Dictionary[int, bool] = {}

	for i in sources.size():
		var node: Node = sources[i]
		if visited.has(node.get_instance_id()):
			continue
		var network := _bfs_network(node, visited)
		if network.sources.size() > 0 or network.pipes.size() > 0:
			_cached_networks.append(network)

	for i in pipes.size():
		var node: Node = pipes[i]
		if visited.has(node.get_instance_id()):
			continue
		var network := _bfs_network(node, visited)
		if network.sources.size() > 0 or network.pipes.size() > 0:
			_cached_networks.append(network)


func _bfs_network(start_node: Node, visited: Dictionary[int, bool]) -> Dictionary:
	if _building_manager == null:
		return {"sources": [], "pipes": [], "containers": []}
	var sources: Array[Node] = []
	var pipes: Array[Node] = []
	var containers: Array[Node] = []
	var container_dict: Dictionary[int, bool] = {} # instance_id -> true，O(1)查找

	var queue: Array[Node] = [start_node]
	var head: int = 0
	visited[start_node.get_instance_id()] = true

	while head < queue.size():
		var node: Node = queue[head]
		head += 1

		if node is WaterSourceNode:
			sources.append(node)
		elif node is PipeNode:
			pipes.append(node)
		elif node is ContainerNode:
			if not container_dict.has(node.get_instance_id()):
				container_dict[node.get_instance_id()] = true
				containers.append(node)

		if not (node is WaterSourceNode or node is PipeNode or node is ContainerNode):
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

			if neighbor is WaterSourceNode or neighbor is PipeNode:
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

	return {
		"sources": sources,
		"pipes": pipes,
		"containers": containers,
	}


func _process_network(network: Dictionary) -> bool:
	if _building_manager == null:
		return false
	var sources: Array[Node] = network.sources
	var pipes: Array[Node] = network.pipes
	var all_containers: Array[Node] = network.containers

	var has_flow: bool = false

	if sources.is_empty() or all_containers.is_empty():
		for pipe: PipeNode in pipes:
			pipe.network_state = 0
		return false

	var total_output: int = 0
	for src: Node in sources:
		if src is WaterSourceNode:
			total_output += src.remaining_output

	if total_output <= 0:
		for pipe: PipeNode in pipes:
			pipe.network_state = 0
		return false

	var candidates: Array[ContainerNode] = []
	var total_space: int = 0
	for container: ContainerNode in all_containers:
		var space: int = container.max_capacity - container.capacity
		if space > 0:
			candidates.append(container)
			total_space += space

	if candidates.is_empty():
		for pipe: PipeNode in pipes:
			pipe.network_state = 2
		return false

	var to_distribute: int = mini(total_output, total_space)

	var per: int = to_distribute / candidates.size()
	var extra: int = to_distribute % candidates.size()

	for i in range(candidates.size()):
		var container: ContainerNode = candidates[i] as ContainerNode
		var amount: int = per
		if i < extra:
			amount += 1
		container.add(amount)
		_sync_building_data(container)
		has_flow = true

	var remaining: int = to_distribute
	for src: Node in sources:
		if src is WaterSourceNode:
			var deducted: int = src.consume_output(remaining)
			remaining -= deducted

	var all_full: bool = true
	for container: ContainerNode in all_containers:
		if container.capacity < container.max_capacity:
			all_full = false
			break
	for pipe: PipeNode in pipes:
		pipe.network_state = 2 if all_full else 1

	return has_flow


func _sync_building_data(node: Node) -> void:
	if _building_manager == null:
		return
	var data: BuildingData = _building_manager.get_building_data(node.grid_position)
	if data == null:
		return
	data.capacity = node.capacity
