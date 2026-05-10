extends Node

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = GameConfig.fluid_tick_interval
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func _on_tick() -> void:
	var all_pipes := get_tree().get_nodes_in_group("pipe")
	var all_sources := get_tree().get_nodes_in_group("water_source")
	var all_network_nodes: Array[Node] = []
	all_network_nodes.append_array(all_pipes)
	all_network_nodes.append_array(all_sources)

	for node in all_pipes:
		if node is PipeNode:
			node.network_state = 0

	if all_network_nodes.is_empty():
		return

	for src in all_sources:
		if src is WaterSourceNode:
			src.remaining_output = src.output_per_tick

	var visited: Dictionary = {}
	var networks: Array[Dictionary] = []

	for node in all_network_nodes:
		if visited.has(node.get_instance_id()):
			continue
		var network := _bfs_network(node, visited)
		if network.sources.size() > 0 or network.pipes.size() > 0:
			networks.append(network)

	var has_flow := false

	for network in networks:
		has_flow = _process_network(network) or has_flow

	if has_flow:
		EventBus.fluid_updated.emit()


func _bfs_network(start_node: Node, visited: Dictionary) -> Dictionary:
	var sources: Array[Node] = []
	var pipes: Array[Node] = []
	var containers: Array[Node] = []

	var queue: Array[Node] = [start_node]
	visited[start_node.get_instance_id()] = true

	while queue.size() > 0:
		var node: Node = queue.pop_front()

		if node is WaterSourceNode:
			sources.append(node)
		elif node is PipeNode:
			pipes.append(node)

		var bm := get_parent()
		var dirs = GridCoordinate.DIR_4

		for dir_idx in 4:
			if node is PipeNode:
				var pipe_node := node as PipeNode
				if (pipe_node.connection_mask & (1 << dir_idx)) == 0:
					continue

			var neighbor_pos: Vector2i = node.grid_position + dirs[dir_idx]

			if not bm.has_building(neighbor_pos):
				continue

			var neighbor: Node = bm.get_building_node(neighbor_pos)
			if neighbor == null:
				continue

			if neighbor is WaterSourceNode or neighbor is PipeNode:
				if neighbor is PipeNode:
					var neighbor_pipe := neighbor as PipeNode
					var opposite_dir := dir_idx ^ 2
					if (neighbor_pipe.connection_mask & (1 << opposite_dir)) == 0:
						continue

				if not visited.has(neighbor.get_instance_id()):
					visited[neighbor.get_instance_id()] = true
					queue.append(neighbor)
			elif neighbor is ContainerNode:
				if not _container_in_array(containers, neighbor):
					containers.append(neighbor)
					if not visited.has(neighbor.get_instance_id()):
						visited[neighbor.get_instance_id()] = true
						queue.append(neighbor)

	return {
		"sources": sources,
		"pipes": pipes,
		"containers": containers,
	}


func _container_in_array(arr: Array[Node], target: Node) -> bool:
	for c in arr:
		if c.get_instance_id() == target.get_instance_id():
			return true
	return false


func _process_network(network: Dictionary) -> bool:
	var sources: Array[Node] = network.sources
	var pipes: Array[Node] = network.pipes
	var containers: Array[Node] = network.containers

	var has_flow := false

	if sources.is_empty() or containers.is_empty():
		for pipe in pipes:
			if pipe is PipeNode:
				pipe.network_state = 0
		return false

	var total_output := 0
	for src in sources:
		if src is WaterSourceNode:
			total_output += src.remaining_output

	if total_output <= 0:
		for pipe in pipes:
			if pipe is PipeNode:
				pipe.network_state = 1
		return false

	var candidates: Array[Node] = []
	var total_space: int = 0
	for container in containers:
		var space: int = container.max_capacity - container.capacity
		if space > 0:
			candidates.append(container)
			total_space += space

	if candidates.is_empty():
		for pipe in pipes:
			if pipe is PipeNode:
				pipe.network_state = 2
		return false

	var to_distribute := mini(total_output, total_space)
	if to_distribute <= 0:
		for pipe in pipes:
			if pipe is PipeNode:
				pipe.network_state = 1
		return false

	var per := to_distribute / candidates.size()
	var extra := to_distribute % candidates.size()

	var bm := get_parent()
	for i in range(candidates.size()):
		var container := candidates[i] as ContainerNode
		var amount := per
		if i < extra:
			amount += 1
		container.add(amount)
		_sync_building_data(container)
		has_flow = true

	var remaining := to_distribute
	for src in sources:
		if src is WaterSourceNode:
			var deduct := mini(remaining, src.remaining_output)
			src.remaining_output -= deduct
			remaining -= deduct

	var all_full := true
	for container in containers:
		if container.capacity < container.max_capacity:
			all_full = false
			break

	for pipe in pipes:
		if pipe is PipeNode:
			pipe.network_state = 2 if all_full else 1

	return has_flow


func _sync_building_data(node: Node) -> void:
	var bm = get_parent()
	if bm != null and bm.has_method("has_building") and bm.buildings.has(node.grid_position):
		bm.buildings[node.grid_position].capacity = node.capacity
