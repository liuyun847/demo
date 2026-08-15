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
## tick 计数器，用于周期性距离/遗弃清理
var _tick_count: int = 0

## 源质服务（依赖注入），未注入时回退到全局 EssencePool
var _essence_service: Variant = null

# ========== 分帧模拟状态（方向 D） ==========
## 一个 tick 的各个阶段：每帧最多执行一个阶段，把单帧峰值分摊到多帧，
## 避免 0.1s Timer 触发时所有模拟工作（收集/扩散/反应/清理）挤在同一帧造成卡顿
enum TickPhase {
	PREP,       ## 产物计时器、收集器、激活源头、脏区域采样、水源重置
	DIFFUSE,    ## 扩散/流动
	REACTIONS,  ## 反应
	CLEANUP,    ## 周期性距离/遗弃清理
	DONE,       ## 哨兵：>= DONE 表示本 tick 完成
}
## Timer 到点后置 true，由 _process 逐帧推进阶段
var _tick_pending: bool = false
## 当前进行到哪个阶段；-1 表示空闲
var _current_phase: int = -1
## 本 tick 跨阶段共享的状态
var _phase_active_sources: Dictionary = {}
var _phase_dirty: Array[Vector2i] = []

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
	# 分帧：Timer 只负责标记，实际工作由 _process 逐帧推进（方向 D）
	_timer.timeout.connect(_on_timer_timeout)
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

## Timer 到点：仅标记待处理，避免在 Timer 回调帧内一次执行全部模拟工作
func _on_timer_timeout() -> void:
	_tick_pending = true

## 每帧推进一个 tick 阶段（方向 D：分帧模拟）
## 若上一 tick 尚未执行完（_current_phase >= 0），新的 Timer 到点只保留 pending 标记，
## 待当前 tick 完成后下一帧再启动新 tick（低帧率下 tick 合并而非堆积）
func _process(_delta: float) -> void:
	if _tick_pending and _current_phase < 0:
		_tick_pending = false
		if _building_manager == null or _paused:
			return
		if _dirty:
			_rebuild_networks()
			_dirty = false
		_current_phase = TickPhase.PREP
	if _current_phase < 0:
		return
	if _paused:
		# 暂停立即冻结模拟：若暂停发生在一个 tick 中途，丢弃剩余阶段（旧版 tick 原子执行，
		# 暂停即刻生效；分帧后不拦截的话，暂停后 1-3 帧内模拟仍会继续推进）。
		# 已采样/已消费的脏区域通过 mark_all_dirty 重新标记，恢复后下一 tick 全量重算，
		# 避免暂停前的移动/产物变化丢失导致元素卡死。
		_current_phase = -1
		_element_grid.mark_all_dirty()
		return
	_run_phase(_current_phase)
	_current_phase += 1
	if _current_phase >= TickPhase.DONE:
		_current_phase = -1

## 同步完整 tick（测试直接调用；语义与分帧路径一致，仅不跨帧）
func _on_tick() -> void:
	if not _building_manager:
		return
	if _paused:
		return

	if _dirty:
		_rebuild_networks()
		_dirty = false

	_run_phase(TickPhase.PREP)
	_run_phase(TickPhase.DIFFUSE)
	_run_phase(TickPhase.REACTIONS)
	_run_phase(TickPhase.CLEANUP)

## 执行单个 tick 阶段
func _run_phase(phase: int) -> void:
	match phase:
		TickPhase.PREP:
			# 递减反应产物存续计时器
			_element_grid.tick_products()

			# 收集器必须在扩散前执行：tick_products 到期后产物变为普通元素，
			# 收集器在扩散前收集，防止产物被后续流程移除
			# 注意：源头新种子需等到下一 tick 才能被收集器收集（收集器在种子产出前执行）
			_process_collectors()

			# 源头产出由扩散系统接管：diffuse_all 内部的 _process_source_buildings 负责种子创建
			# 仅允许连通到核心的源头产出种子，未连通的源头不工作
			_phase_active_sources = _collect_active_source_positions()

			# 采样本 tick 的脏区域（收集器移除元素会产生脏区域）
			_phase_dirty = _element_grid.take_dirty()

			# 每 tick 清空水源标记，由 _process_source_buildings 按当前源头类型/状态重新标记。
			# 保证源头切换类型后，旧类型元素体立即失去水源（只自然滑动、不再扩张消耗源质）。
			# 被清空水源的格子会标记脏区域，纳入本 tick 扩散重算。
			_element_grid.clear_all_sources()
		TickPhase.DIFFUSE:
			_element_diffusion.diffuse_all(_element_grid, _phase_active_sources, _phase_dirty)
		TickPhase.REACTIONS:
			# 增量反应扫描 = PREP 采样的脏区域（放置/移除/收集器移除等静态相邻对）+
			# 扩散阶段新产生的脏区域（移动/新元素）。
			# 若不合并 PREP 脏区域：静态相邻的反应对（如被砖块围死的水+火）在扩散无
			# 变化时不产生新脏区域，将永远不被扫描，反应永不触发（旧版全量扫描每 tick 触发）。
			# peek（不消费）保留脏标记：反应产物下一 tick 仍会进入扩散重算，避免产物冻结
			var reaction_dirty: Array[Vector2i] = []
			reaction_dirty.assign(_phase_dirty)
			reaction_dirty.append_array(_element_grid.peek_dirty())
			_reaction_processor.process_all(reaction_dirty)
		TickPhase.CLEANUP:
			# 周期性距离/遗弃清理：移除移出边界的元素（无源元素仅滑动不增殖，由这里兜底回收）
			_tick_count += 1
			if _tick_count >= GameConfig.CLEANUP_INTERVAL_TICKS:
				_tick_count = 0
				var core_pos: Vector2i = Vector2i.ZERO
				if _building_manager.core_node != null and is_instance_valid(_building_manager.core_node):
					core_pos = _building_manager.core_node.grid_position
				_element_diffusion.cleanup_abandoned(_element_grid, core_pos)

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
	# 建筑占据/释放格子改变元素可达性，标记全量脏区域（低频事件，全量可接受）
	_element_grid.mark_all_dirty()

func _on_building_removed(grid_pos: Vector2i) -> void:
	_dirty = true
	_cached_networks.clear()
	# 立即清除所有水源标记，被移除的建筑不再能维持水源。
	# 每 tick 也会清空重建（PREP 阶段），此处立即生效避免移除后残留标记。
	_element_grid.clear_all_sources()
	# 取消注册源头建筑（erase 安全，非源头位置无副作用）
	_element_grid.unregister_source_building(grid_pos)
	# 建筑占据/释放格子改变元素可达性，标记全量脏区域（低频事件，全量可接受）
	_element_grid.mark_all_dirty()

func mark_dirty() -> void:
	_dirty = true
	_cached_networks.clear()

func _on_pause_state_changed(paused: bool) -> void:
	_paused = paused

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
