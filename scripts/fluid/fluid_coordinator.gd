class_name ReactionCoordinator
extends Node

var _timer: Timer = null
var _building_manager: BuildingManager = null

var _dirty: bool = true
var _cached_networks: Array[Dictionary] = []

func init(building_manager: BuildingManager) -> void:
	_building_manager = building_manager

func _ready() -> void:
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
	_cached_networks.clear()

func mark_dirty() -> void:
	_dirty = true
	_cached_networks.clear()

func _on_tick() -> void:
	if not _building_manager:
		return
	var all_pipes: Array[PipeNode] = _building_manager.fluid_pipes

	if all_pipes.is_empty():
		_cached_networks.clear()
		_dirty = false
		return

	if _dirty:
		_rebuild_networks(all_pipes)
		_dirty = false

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
		if network.pipes.size() > 0 or network.containers.size() > 0:
			_cached_networks.append(network)


func _bfs_network(start_node: Node, visited: Dictionary[int, bool]) -> Dictionary:
	if _building_manager == null:
		return {"pipes": [], "containers": []}
	var pipes: Array[Node] = []
	var containers: Array[Node] = []
	var container_dict: Dictionary[int, bool] = {}

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

	return {
		"pipes": pipes,
		"containers": containers,
	}
