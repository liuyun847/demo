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
func diffuse_all(element_grid: ElementGrid) -> void:
	var bodies: Array[ElementBody] = _detect_element_bodies(element_grid)
	for body: ElementBody in bodies:
		var type_data: ElementTypeData = ElementRegistry.get_element_type(body.element_id)
		if type_data == null:
			continue

		match type_data.state:
			"solid":
				# 固体不扩散也不收缩
				continue
			"gas":
				if body.has_source:
					_expand_body(element_grid, body, true)
				else:
					_shrink_body(element_grid, body, true)
			_:  # liquid 及其他默认为液体行为
				if body.has_source:
					_expand_body(element_grid, body, false)
				else:
					_shrink_body(element_grid, body, false)

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
		body.min_source_y = 999999
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
	var cost_per_cell: float = GameConfig.emitter_essence_cost_per_tick
	var total_cost: float = total_to_expand * cost_per_cell

	var es: Variant = _get_essence()
	if not es.has(total_cost):
		return

	var count: int = 0
	for pos: Vector2i in candidates:
		if count >= total_to_expand:
			break
		if element_grid.set_element(pos, element_id, body.min_source_y):
			es.subtract(cost_per_cell)
			count += 1

## 无源区域收缩
## upward: true=气体(优先移除下方), false=液体(优先移除上方)
func _shrink_body(element_grid: ElementGrid, body: ElementBody, upward: bool) -> void:
	if body.cells.is_empty():
		return

	var sorted: Array[Vector2i] = body.cells.duplicate()

	# 液体: 优先移除 Y 较小（上方）；气体: 优先移除 Y 较大（下方）
	if upward:
		sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	else:
		sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)

	# 过滤掉有存续标记的格子（反应产物在存续期内不收缩）
	var removable: Array[Vector2i] = sorted.filter(
		func(pos: Vector2i) -> bool: return not element_grid.is_product(pos)
	)
	if removable.is_empty():
		return

	var remove_count: int = min(removable.size(), 3)
	for i in range(remove_count):
		element_grid.remove_element(removable[i])
