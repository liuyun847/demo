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
			body.rate = maxi(source_count, 1)

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

	var count: int = 0
	for pos: Vector2i in candidates:
		if count >= body.rate:
			break
		element_grid.set_fluid(pos, body.min_source_y)
		count += 1
