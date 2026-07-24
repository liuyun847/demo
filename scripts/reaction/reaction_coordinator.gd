class_name ReactionCoordinator
extends Node

var _timer: Timer = null
var _building_manager: BuildingManager = null

var _dirty: bool = true
var _cached_networks: Array[Dictionary] = []

var _element_grid: ElementGrid = null
var _element_diffusion: ElementDiffusion = null
var _reaction_registry: ReactionRegistry = null
var _reaction_processor: ReactionProcessor = null

var _paused: bool = false

## 源质服务（依赖注入），未注入时回退到全局 EssencePool
var _essence_service: Variant = null

func init(building_manager: BuildingManager) -> void:
	_building_manager = building_manager

## 注入源质服务（用于测试解耦）
func set_essence_service(service: Variant) -> void:
	_essence_service = service

## 获取源质服务，未注入时回退到全局 EssencePool
func _get_essence() -> Variant:
	if _essence_service == null:
		return EssencePool
	return _essence_service

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.pause_state_changed.connect(_on_pause_state_changed)
	_timer = Timer.new()
	_timer.wait_time = GameConfig.SIMULATION_TICK_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_element_grid = ElementGrid.new()
	_element_grid.building_manager_ref = _building_manager
	add_child(_element_grid)

	_element_diffusion = ElementDiffusion.new()
	_element_diffusion.set_essence_service(_get_essence())
	add_child(_element_diffusion)

	# 反应系统
	_reaction_registry = ReactionRegistry.new()
	_register_default_reactions()
	_reaction_processor = ReactionProcessor.new(_reaction_registry, _element_grid, _get_essence())

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
	# 清除放置位置的元素，防止建筑建在元素上
	if _element_grid.has_element(grid_pos):
		_element_grid.remove_element(grid_pos)
	# 若放置的是源头建筑，注册到 element_grid 供扩散系统使用
	var placed_node: Node = _building_manager.get_building_node(grid_pos)
	if placed_node is SourceNode:
		_element_grid.register_source_building(grid_pos)

func _on_building_removed(grid_pos: Vector2i) -> void:
	_dirty = true
	_cached_networks.clear()
	# 清除所有水源标记，被移除的建筑不再能维持水源
	# 下个 tick 的 _process_source_buildings() 会为仍然存在的源头重新标记
	_element_grid.clear_all_sources()
	# 取消注册源头建筑（erase 安全，非源头位置无副作用）
	_element_grid.unregister_source_building(grid_pos)

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

	# 递减反应产物存续计时器
	_element_grid.tick_products()

	# 收集器必须在扩散前执行：tick_products 到期后产物变为普通元素，
	# 扩散系统的 _shrink_body 会移除无源元素，必须在收集器收集之后再收缩
	# 注意：源头新种子需等到下一 tick 才能被收集器收集（收集器在种子产出前执行）
	_process_collectors()

	# 源头产出由扩散系统接管：diffuse_all 内部的 _process_source_buildings 负责种子创建
	# 仅允许连通到核心的源头产出种子，未连通的源头不工作
	var active_source_positions: Dictionary = _collect_active_source_positions()
	_element_diffusion.diffuse_all(_element_grid, active_source_positions)

	_reaction_processor.process_all()

## 收集所有连通到核心的网络中的源头位置（Dictionary{Vector2i: bool}）
## 用于限制只有连通核心的源头才产出元素
func _collect_active_source_positions() -> Dictionary:
	var result: Dictionary = {}
	for network: Dictionary in _cached_networks:
		for source: SourceNode in network.sources:
			if is_instance_valid(source):
				result[source.grid_position] = true
	return result

func _process_collectors() -> void:
	var es: Variant = _get_essence()
	for network: Dictionary in _cached_networks:
		for collector: CollectorNode in network.collectors:
			var collected: float = collector.try_collect(_element_grid)
			if collected > 0.0:
				es.add(collected)

func _rebuild_networks() -> void:
	_cached_networks.clear()

	var core: CoreNode = _building_manager.core_node
	if core == null or not is_instance_valid(core):
		return

	var visited: Dictionary[int, bool] = {}

	# 从核心的四个邻居开始 BFS
	# 除了砖块，其他建筑和管道一样视为连通
	var core_cells: Array[Vector2i] = GameConfig.CORE_CELLS
	for cell: Vector2i in core_cells:
		for dir: Vector2i in GridCoordinate.DIR_4:
			var neighbor_pos: Vector2i = cell + dir
			var neighbor: Node = _building_manager.get_building_node(neighbor_pos)
			if neighbor == null:
				continue
			if visited.has(neighbor.get_instance_id()):
				continue
			if not neighbor is BrickNode and not neighbor is CoreNode:
				visited[neighbor.get_instance_id()] = true
				var network := _bfs_network(neighbor, visited)
				if network.pipes.size() > 0 or \
				   network.sources.size() > 0 or network.collectors.size() > 0:
					_cached_networks.append(network)

func _bfs_network(start_node: Node, visited: Dictionary[int, bool]) -> Dictionary:
	if _building_manager == null:
		return {"pipes": [], "sources": [], "collectors": []}

	var pipes: Array[Node] = []
	var sources: Array[SourceNode] = []
	var source_dict: Dictionary[int, bool] = {}
	var collectors: Array[CollectorNode] = []
	var collector_dict: Dictionary[int, bool] = {}

	var queue: Array[Node] = [start_node]
	var head: int = 0

	while head < queue.size():
		var node: Node = queue[head]
		head += 1

		if node is PipeNode:
			pipes.append(node)
		elif node is SourceNode:
			if not source_dict.has(node.get_instance_id()):
				source_dict[node.get_instance_id()] = true
				sources.append(node)
		elif node is CollectorNode:
			if not collector_dict.has(node.get_instance_id()):
				collector_dict[node.get_instance_id()] = true
				collectors.append(node)

		# 除了砖块，其他建筑和管道一样视为连通
		if node is BrickNode or node is CoreNode:
			continue

		var dirs: Array[Vector2i] = GridCoordinate.DIR_4

		for dir_idx: int in 4:
			# 管道按 connection_mask 过滤方向；非管道建筑（源头/收集器）全方向连通
			if node is PipeNode:
				var pipe_node: PipeNode = node as PipeNode
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
			elif neighbor is SourceNode:
				var nid: int = neighbor.get_instance_id()
				# 同时检查局部 source_dict 和全局 visited，
				# 防止直连 core 分支已加入的节点被 BFS 再次加入
				if not visited.has(nid) and not source_dict.has(nid):
					source_dict[nid] = true
					visited[nid] = true
					sources.append(neighbor)
					queue.append(neighbor)  # 非砖块建筑也继续传播 BFS
			elif neighbor is CollectorNode:
				var nid: int = neighbor.get_instance_id()
				# 同时检查局部 collector_dict 和全局 visited
				if not visited.has(nid) and not collector_dict.has(nid):
					collector_dict[nid] = true
					visited[nid] = true
					collectors.append(neighbor)
					queue.append(neighbor)  # 非砖块建筑也继续传播 BFS

	return {
		"pipes": pipes,
		"sources": sources,
		"collectors": collectors,
	}

## 注册默认反应规则
func _register_default_reactions() -> void:
	# 水 + 火 → 蒸汽 + 副产物源质
	_reaction_registry.register("water", "fire", "steam", 0.0)
