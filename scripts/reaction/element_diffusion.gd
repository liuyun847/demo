class_name ElementDiffusion
extends Node

class WaterBody:
	var cells: Array[Vector2i]
	var has_source: bool
	var min_source_y: int
	var rate: int

func _init() -> void:
	pass

func diffuse_all(element_grid: ElementGrid) -> void:
	var bodies: Array[WaterBody] = _detect_water_bodies(element_grid)
	for body: WaterBody in bodies:
		if body.has_source:
			_expand_body(element_grid, body)
		else:
			_shrink_body(element_grid, body)

func _detect_water_bodies(element_grid: ElementGrid) -> Array[WaterBody]:
	var visited: Dictionary = {}
	var bodies: Array[WaterBody] = []

	for pos: Vector2i in element_grid.get_all_fluid_positions():
		if visited.has(pos):
			continue

		var body := WaterBody.new()
		body.cells = []
		body.has_source = false
		body.min_source_y = 999999
		body.rate = 1

		var queue: Array[Vector2i] = []
		queue.push_back(pos)
		visited[pos] = true

		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			body.cells.append(current)

			if element_grid.is_source_pos(current):
				body.has_source = true
				var sy: int = element_grid.get_source_y(current)
				if sy < body.min_source_y:
					body.min_source_y = sy

			for dir: Vector2i in GridCoordinate.DIR_4:
				var neighbor: Vector2i = current + dir
				if not element_grid.has_fluid(neighbor):
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

func _expand_body(element_grid: ElementGrid, body: WaterBody) -> void:
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}

	for cell: Vector2i in body.cells:
		for dir: Vector2i in GridCoordinate.DIR_4:
			var neighbor: Vector2i = cell + dir
			if element_grid.is_position_available(neighbor) and neighbor.y >= body.min_source_y:
				if not seen.has(neighbor):
					seen[neighbor] = true
					candidates.append(neighbor)

	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)

	var total_to_expand: int = min(candidates.size(), body.rate)
	var cost_per_cell: float = GameConfig.emitter_essence_cost_per_tick
	var total_cost: float = total_to_expand * cost_per_cell

	if not EssencePool.has(total_cost):
		return

	var count: int = 0
	for pos: Vector2i in candidates:
		if count >= total_to_expand:
			break
		if element_grid.set_fluid(pos, body.min_source_y):
			EssencePool.subtract(cost_per_cell)
			count += 1

# 断开连接的水体：逐 tick 逐渐缩小直至消失
func _shrink_body(element_grid: ElementGrid, body: WaterBody) -> void:
	if body.cells.is_empty():
		return

	# 按 Y 升序排列，优先移除 Y 较小（位置较高）的细胞，模拟从上往下的干涸效果
	var sorted: Array[Vector2i] = body.cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)

	# 每 tick 移除 min(细胞数量, 3) 个细胞，实现逐渐缩小
	var remove_count: int = min(sorted.size(), 3)
	for i in range(remove_count):
		var pos: Vector2i = sorted[i]
		element_grid.remove_fluid(pos)
