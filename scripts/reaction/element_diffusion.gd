class_name ElementDiffusion
extends Node

## 源质服务（依赖注入），未注入时回退到全局 EssencePool
var _essence_service: Variant = null

## 元素连通区域
class ElementBody:
	var cells: Array[Vector2i]           ## 区域包含的格子
	var element_id: String               ## 元素类型ID
	var has_source: bool                 ## 是否有水源
	var min_source_y: int                ## 水源中最小的 Y 值
	var rate: int                        ## 扩散速率（= 水源数量，至少为 1）

## 注入源质服务（用于测试解耦）
func set_essence_service(service: Variant) -> void:
	_essence_service = service

## 获取源质服务，未注入时回退到全局 EssencePool
func _get_essence() -> Variant:
	if _essence_service == null:
		return EssencePool
	return _essence_service

func _init() -> void:
	pass

## 主入口：对所有元素执行扩散/收缩
## active_source_positions: 可选，激活源头位置集合（Dictionary{Vector2i: bool}）。
##   - null（默认）: 处理所有已注册源头（向后兼容，测试用）
##   - 非空 Dictionary: 仅处理位置在集合中的源头（由 ReactionCoordinator 传入连通核心的源头）
func diffuse_all(element_grid: ElementGrid, active_source_positions: Variant = null) -> void:
	# 先处理源头建筑：每源头每 tick 最多创建 1 个种子元素并 mark_as_source
	_process_source_buildings(element_grid, active_source_positions)
	var bodies: Array[ElementBody] = _detect_element_bodies(element_grid)
	for body: ElementBody in bodies:
		var type_data: ElementTypeData = ElementRegistry.get_element_type(body.element_id)
		if type_data == null:
			continue

		match type_data.state:
			ElementTypeData.State.SOLID:
				# 固体不扩散也不收缩
				continue
			ElementTypeData.State.GAS:
				if body.has_source:
					_expand_body(element_grid, body, true)
				else:
					_shrink_body(element_grid, body, true)
			_:  # LIQUID 及其他默认为液体行为
				if body.has_source:
					_expand_body(element_grid, body, false)
				else:
					_shrink_body(element_grid, body, false)


## 源头种子产出：每源头每 tick 最多创建 1 个种子（免费）
## - 若相邻已有同类型元素 → mark_as_source（免费维持）
## - 若无 → 按元素扩散自然方向找空格创建种子 + mark_as_source
## 源质不在此处消耗，仅在元素扩散扩张时消耗（_expand_body）
## 元素类型从 SourceNode 节点实时读取（用户可能通过面板修改）
## active_source_positions: 可选，激活源头位置集合。null=处理所有已注册源头；
##   非空 Dictionary=仅处理位置在集合中的源头（用于限制只有连通核心的源头产出）
func _process_source_buildings(element_grid: ElementGrid, active_source_positions: Variant = null) -> void:
	if element_grid.building_manager_ref == null:
		return
	var sources: Dictionary = element_grid.get_source_buildings()
	for pos: Vector2i in sources:
		# 若提供了激活源头集合，仅处理集合中的源头（未连通核心的源头不产出）
		if active_source_positions != null and not active_source_positions.has(pos):
			continue
		var node: Node = element_grid.building_manager_ref.get_building_node(pos)
		if node == null or not (node is SourceNode):
			continue
		var source_node: SourceNode = node as SourceNode
		# 未选类型不产出（等待用户通过面板选择）
		if not source_node.has_type_selected():
			continue
		var element_id: String = source_node.element_type_id
		var type_data: ElementTypeData = ElementRegistry.get_element_type(element_id)
		if type_data == null:
			continue
		# 1. 检查 DIR_4 四邻格是否已有同类型元素，有则 mark_as_source 维持（免费）
		var found_adjacent: bool = false
		for dir: Vector2i in GridCoordinate.DIR_4:
			var npos: Vector2i = pos + dir
			if element_grid.has_element(npos) and \
				element_grid.get_element_id(npos) == element_id:
				element_grid.mark_as_source(npos)
				found_adjacent = true
				break  # 只需标记一个即可维持
		if found_adjacent:
			continue
		# 2. 无相邻同类型 → 按扩散方向找空格创建种子（免费）
		var seed_pos: Vector2i = _find_seed_position(element_grid, pos, type_data.state)
		if seed_pos == GameConfig.INVALID_GRID_POS:
			continue
		if element_grid.set_element(seed_pos, element_id, seed_pos.y):
			element_grid.mark_as_source(seed_pos)


## 按元素状态选择种子位置：液体优先 DOWN，气体优先 UP，回退 DIR_4 顺序
func _find_seed_position(element_grid: ElementGrid, source_pos: Vector2i, state: int) -> Vector2i:
	var priority_dirs: Array[Vector2i]
	match state:
		ElementTypeData.State.LIQUID:
			# DOWN/LEFT/RIGHT/UP（液体自然向下扩散）
			priority_dirs = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
		ElementTypeData.State.GAS:
			# UP/LEFT/RIGHT/DOWN（气体自然向上扩散）
			priority_dirs = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
		_:
			priority_dirs = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for dir: Vector2i in priority_dirs:
		var npos: Vector2i = source_pos + dir
		if element_grid.is_position_available(npos):
			return npos
	return GameConfig.INVALID_GRID_POS

## 检测所有连通元素区域，按元素类型分别检测
func _detect_element_bodies(element_grid: ElementGrid) -> Array[ElementBody]:
	var visited: Dictionary = {}
	var bodies: Array[ElementBody] = []

	for pos: Vector2i in element_grid.get_all_element_positions():
		if visited.has(pos):
			continue

		var element_id: String = element_grid.get_element_id(pos)
		var body := ElementBody.new()
		body.cells = []
		body.element_id = element_id
		body.has_source = false
		body.min_source_y = GameConfig.SOURCE_Y_SENTINEL
		body.rate = 1

		var queue: Array[Vector2i] = []
		queue.push_back(pos)
		visited[pos] = true

		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()

			# 只连接同类型元素
			var current_id: String = element_grid.get_element_id(current)
			if current_id != element_id:
				continue

			body.cells.append(current)

			if element_grid.is_source_pos(current):
				body.has_source = true
				var sy: int = element_grid.get_source_y(current)
				if sy < body.min_source_y:
					body.min_source_y = sy

			for dir: Vector2i in GridCoordinate.DIR_4:
				var neighbor: Vector2i = current + dir
				if not element_grid.has_element(neighbor):
					continue
				if element_grid.get_element_id(neighbor) != element_id:
					continue
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		if body.has_source:
			var source_count: int = 0
			for cell: Vector2i in body.cells:
				if element_grid.is_source_pos(cell):
					source_count += 1
			body.rate = max(source_count, 1)

		bodies.append(body)

	return bodies

## 有源区域扩张
## upward: true=向上扩散(气体), false=向下扩散(液体)
func _expand_body(element_grid: ElementGrid, body: ElementBody, upward: bool) -> void:
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	var element_id: String = body.element_id

	for cell: Vector2i in body.cells:
		for dir: Vector2i in GridCoordinate.DIR_4:
			var neighbor: Vector2i = cell + dir
			if element_grid.is_position_available(neighbor):
				# 液体限制在 min_source_y 以上，气体不限制（向上扩散）
				if not upward and neighbor.y < body.min_source_y:
					continue
				if not seen.has(neighbor):
					seen[neighbor] = true
					candidates.append(neighbor)

	if candidates.is_empty():
		return

	# 液体: 优先向下 (Y 降序)；气体: 优先向上 (Y 升序)
	if upward:
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	else:
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)

	var total_to_expand: int = min(candidates.size(), body.rate)
	var cost_per_cell: float = GameConfig.SOURCE_ESSENCE_COST_PER_TICK

	var es: Variant = _get_essence()
	# 逐个检查可负担性，避免源质够 1 个不够 N 个时一个都不扩张
	var count: int = 0
	for pos: Vector2i in candidates:
		if count >= total_to_expand:
			break
		if not es.has(cost_per_cell):
			break  # 源质不足，停止扩张
		if element_grid.set_element(pos, element_id, body.min_source_y):
			es.subtract(cost_per_cell)
			count += 1

## 无源区域收缩
## upward: true=气体(均匀收缩), false=液体(优先移除上方)
func _shrink_body(element_grid: ElementGrid, body: ElementBody, upward: bool) -> void:
	if body.cells.is_empty():
		return

	# 过滤掉有存续标记的格子（反应产物在存续期内不收缩）
	var removable: Array[Vector2i] = body.cells.filter(
		func(pos: Vector2i) -> bool: return not element_grid.is_product(pos)
	)
	if removable.is_empty():
		return

	if upward:
		# 气体：均匀收缩，从边缘开始
		_shrink_uniform(element_grid, removable)
	else:
		# 液体：保持原逻辑，优先移除上方（Y 较小）
		var sorted: Array[Vector2i] = removable.duplicate()
		sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
		var remove_count: int = min(sorted.size(), 3)
		for i in range(remove_count):
			element_grid.remove_element(sorted[i])

## 气体均匀收缩：从边缘开始，按 (x+y) 升序确定性排序
func _shrink_uniform(element_grid: ElementGrid, cells: Array[Vector2i]) -> void:
	var cell_set: Dictionary = {}
	for c: Vector2i in cells:
		cell_set[c] = true

	# 找边缘格子：至少有一个 DIR_4 邻居不在 body 中
	var edges: Array[Vector2i] = []
	for c: Vector2i in cells:
		for dir: Vector2i in GridCoordinate.DIR_4:
			if not cell_set.has(c + dir):
				edges.append(c)
				break

	# 确定性排序（按 x+y 升序，保持稳定行为，不使用随机）
	edges.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a.x + a.y) < (b.x + b.y))

	# 收缩速率：max(3, body 大小 / 10)，适配大 body
	var rate: int = max(3, cells.size() / 10)
	var remove_count: int = min(edges.size(), rate)

	# 边缘不足时从内部按 (x+y) 升序补充
	if remove_count < rate and remove_count < cells.size():
		var non_edges: Array[Vector2i] = cells.filter(
			func(c: Vector2i) -> bool: return not edges.has(c)
		)
		non_edges.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a.x + a.y) < (b.x + b.y))
		for i in range(min(non_edges.size(), rate - remove_count)):
			edges.append(non_edges[i])
		remove_count = min(edges.size(), rate)

	for i in range(remove_count):
		element_grid.remove_element(edges[i])
