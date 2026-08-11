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

## 静态 Y 比较器：避免扩散排序每 tick 创建 lambda 闭包
static func _cmp_y_asc(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y

static func _cmp_y_desc(a: Vector2i, b: Vector2i) -> bool:
	return a.y > b.y

## 主入口：对所有元素执行扩散
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
					# 无源气体仅自然上滑（格子数不变），移出边界由距离清理回收
					_flow_no_source(element_grid, body, true)
			_:  # LIQUID 及其他默认为液体行为
				if body.has_source:
					_expand_body(element_grid, body, false)
				else:
					# 无源液体仅自然下滑（格子数不变），移出边界由距离清理回收
					_flow_no_source(element_grid, body, false)


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
		body.rate = 0  # BFS 中累计水源数，最后 max(rate, 1)

		# 用 head 指针代替 pop_front：pop_front 是 O(n) 的头部弹出，
		# 元素量大时 BFS 总复杂度退化到 O(n²)
		var queue: Array[Vector2i] = [pos]
		var head: int = 0
		visited[pos] = true

		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1

			# 队列中的格子入队前已确认与 element_id 同类型，起点类型在外层已读取，
			# 无需每次循环重复 get_element_id 校验
			body.cells.append(current)

			if element_grid.is_source_pos(current):
				body.has_source = true
				body.rate += 1  # 顺带累计水源数，避免 BFS 后再遍历一次 body.cells
				var sy: int = element_grid.get_source_y(current)
				if sy < body.min_source_y:
					body.min_source_y = sy

			for dir: Vector2i in GridCoordinate.DIR_4:
				var neighbor: Vector2i = current + dir
				# 内联 get_element_id：无元素时返回 ""，一次字典查询替代 has+get 两次方法调用
				if element_grid._elements.get(neighbor, "") != element_id:
					continue
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		body.rate = max(body.rate, 1)

		bodies.append(body)

	return bodies

## 有源区域扩张（消耗源质）
## upward: true=向上扩散(气体), false=向下扩散(液体)
func _expand_body(element_grid: ElementGrid, body: ElementBody, upward: bool) -> void:
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	var element_id: String = body.element_id

	for cell: Vector2i in body.cells:
		for dir: Vector2i in GridCoordinate.DIR_4:
			var neighbor: Vector2i = cell + dir
			# 内联 is_position_available：热路径直接查内部字典，避免每格方法分派开销
			if element_grid._elements.has(neighbor):
				continue
			if element_grid.is_building_at(neighbor):
				continue
			# 液体限制在 min_source_y 以下（不高于最高水源）
			if not upward and neighbor.y < body.min_source_y:
				continue
			if not seen.has(neighbor):
				seen[neighbor] = true
				candidates.append(neighbor)

	if candidates.is_empty():
		return

	# 液体: 优先向下 (Y 降序)；气体: 优先向上 (Y 升序)
	if upward:
		candidates.sort_custom(_cmp_y_asc)
	else:
		candidates.sort_custom(_cmp_y_desc)

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
		# 仅在成功放置后才扣除源质，避免 set_element 失败仍消耗
		if element_grid.set_element(pos, element_id, body.min_source_y):
			es.subtract(cost_per_cell)
			count += 1

## 无源区域自然流动（不增殖）：格子总数不变，元素仅沿自然方向滑动
## 液体优先向下、气体优先向上，主方向被堵时尝试左右；移出距离边界由 cleanup_abandoned 回收。
## 处理顺序按流动方向从外到内，避免同 tick 内元素互相追逐目标格。
func _flow_no_source(element_grid: ElementGrid, body: ElementBody, upward: bool) -> void:
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1) if not upward else Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
	]
	# 液体从下往上处理（Y 降序），气体从上往下处理（Y 升序）。
	# 按行分桶替代全局 sort_custom：构建 O(n)，按 y 序处理行即可，避免 O(n log n) 排序。
	# 行内元素只移向空位；同行竞争同一空位时先处理者占位——原全局 sort 对同 y 行
	# 顺序本就不确定（不稳定排序），分桶顺序与之等价，不影响格子数/方向/速率不变量
	var buckets: Dictionary = {}
	var min_y: int = 0
	var max_y: int = 0
	var first: bool = true
	for cell: Vector2i in body.cells:
		if first:
			min_y = cell.y
			max_y = cell.y
			first = false
		elif cell.y < min_y:
			min_y = cell.y
		elif cell.y > max_y:
			max_y = cell.y
		var row: Variant = buckets.get(cell.y)
		if row == null:
			row = []
			buckets[cell.y] = row
		row.append(cell)

	if upward:
		for y in range(min_y, max_y + 1):
			var row: Variant = buckets.get(y)
			if row != null:
				_flow_row(element_grid, row, dirs)
	else:
		for y in range(max_y, min_y - 1, -1):
			var row: Variant = buckets.get(y)
			if row != null:
				_flow_row(element_grid, row, dirs)

## 按行处理元素流动（液体逐行自下而上、气体逐行自上而下调用）
func _flow_row(element_grid: ElementGrid, row: Array, dirs: Array[Vector2i]) -> void:
	for cell: Vector2i in row:
		if not element_grid._elements.has(cell):
			continue  # 已在此次流动中被移动
		for dir: Vector2i in dirs:
			var target: Vector2i = cell + dir
			# 内联 is_position_available：热路径直接查内部字典，避免每格方法分派开销
			if element_grid._elements.has(target):
				continue
			if element_grid.is_building_at(target):
				continue
			# 用 move_element 搬移：保留产物存续计时器/水源标记，
			# 避免反应产物在无源滑动后被收集器提前收走
			if element_grid.move_element(cell, target):
				break  # 成功移动一格后停止尝试其他方向
			# 放置失败（防御）则继续尝试下一个方向

## 距离/遗弃清理：移除距参照点（默认核心原点）切比雪夫距离超过 ELEMENT_ABANDON_DISTANCE 的元素
## 这是元素回收的兜底手段：无源元素流动移出边界、或远离核心的元素，由这里周期性清理。
## 扩展点：后续如需区分原料与反应产物，可在此对产物豁免或延长寿命。
func cleanup_abandoned(element_grid: ElementGrid, reference_pos: Vector2i = Vector2i.ZERO) -> void:
	var threshold: int = GameConfig.ELEMENT_ABANDON_DISTANCE
	var to_remove: Array[Vector2i] = []
	for pos: Vector2i in element_grid.get_all_element_positions():
		var dist: int = max(abs(pos.x - reference_pos.x), abs(pos.y - reference_pos.y))
		if dist > threshold:
			to_remove.append(pos)
	for pos: Vector2i in to_remove:
		element_grid.remove_element(pos)
