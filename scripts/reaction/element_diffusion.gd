class_name ElementDiffusion
extends Node

const DIR_UP: Vector2i = Vector2i(0, -1)
const DIR_DOWN: Vector2i = Vector2i(0, 1)
const DIR_LEFT: Vector2i = Vector2i(-1, 0)
const DIR_RIGHT: Vector2i = Vector2i(1, 0)

var _tick_count: int = 0

func diffuse_all(element_grid: ElementGrid, steps: int) -> int:
	var total_new_cells: int = 0
	for _i in range(steps):
		total_new_cells += _diffuse_single_step(element_grid)

	_tick_count += 1
	if _tick_count % GameConfig.cleanup_interval_ticks == 0:
		_cleanup_abandoned_elements(element_grid)

	return total_new_cells

func _diffuse_single_step(element_grid: ElementGrid) -> int:
	var current_positions: Array[Vector2i] = element_grid.get_all_element_positions()
	current_positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)

	var total_new_cells: int = 0

	var p1_placements: Dictionary = {}
	var solid_blocked: Array[Vector2i] = []
	for pos: Vector2i in current_positions:
		var element: ElementData = element_grid.get_element(pos)
		if element == null:
			continue

		var down_pos := pos + DIR_DOWN
		if _can_place(down_pos, p1_placements, element_grid):
			_place_copy(element, down_pos, p1_placements)
		elif element_grid.is_building_at(down_pos):
			solid_blocked.append(pos)
	total_new_cells += _commit_placements(element_grid, p1_placements)

	for target: Vector2i in p1_placements:
		var below := target + DIR_DOWN
		if element_grid.is_building_at(below):
			solid_blocked.append(target)

	var p2_placements: Dictionary = {}
	var horizontal_blocked: Array[Vector2i] = []
	for pos: Vector2i in solid_blocked:
		var element: ElementData = element_grid.get_element(pos)
		if element == null:
			continue

		var placed_any := false
		var left_blocked_by_building := false
		var right_blocked_by_building := false

		var left_pos := pos + DIR_LEFT
		if _can_place(left_pos, p2_placements, element_grid):
			_place_copy(element, left_pos, p2_placements)
			placed_any = true
		elif element_grid.is_building_at(left_pos):
			left_blocked_by_building = true

		var right_pos := pos + DIR_RIGHT
		if _can_place(right_pos, p2_placements, element_grid):
			_place_copy(element, right_pos, p2_placements)
			placed_any = true
		elif element_grid.is_building_at(right_pos):
			right_blocked_by_building = true

		if not placed_any and (left_blocked_by_building or right_blocked_by_building):
			horizontal_blocked.append(pos)
	total_new_cells += _commit_placements(element_grid, p2_placements)

	var p3_placements: Dictionary = {}
	var up_queue: Array[Vector2i] = horizontal_blocked.duplicate()
	while not up_queue.is_empty():
		var next_queue: Array[Vector2i] = []
		for pos: Vector2i in up_queue:
			var element: ElementData = element_grid.get_element(pos)
			if element == null:
				continue

			var up_pos := pos + DIR_UP
			if up_pos.y < element.source_y:
				continue
			if element_grid.is_building_at(up_pos):
				continue
			if up_pos in p3_placements:
				continue

			_place_copy(element, up_pos, p3_placements)
			next_queue.append(up_pos)
		up_queue = next_queue
	total_new_cells += _commit_placements(element_grid, p3_placements)

	return total_new_cells


func _commit_placements(element_grid: ElementGrid, placements: Dictionary) -> int:
	var count: int = 0
	for target: Vector2i in placements:
		var data: ElementData = placements[target] as ElementData
		if element_grid.set_element(target, data):
			count += 1
	return count

func _can_place(target: Vector2i, new_placements: Dictionary, element_grid: ElementGrid) -> bool:
	if target in new_placements:
		return false
	return element_grid.is_position_available(target)

func _place_copy(element: ElementData, target: Vector2i, new_placements: Dictionary) -> void:
	var new_element := ElementData.new()
	new_element.element_type = element.element_type
	new_element.complexity = element.complexity
	new_element.source_y = element.source_y
	new_placements[target] = new_element

func _cleanup_abandoned_elements(element_grid: ElementGrid) -> void:
	if element_grid.building_manager_ref == null:
		return

	var building_positions: Array[Vector2i] = element_grid.building_manager_ref.get_all_building_positions()
	if building_positions.is_empty():
		return

	var threshold := GameConfig.element_abandon_distance
	var all_positions: Array[Vector2i] = element_grid.get_all_element_positions()

	for pos: Vector2i in all_positions:
		var min_distance: int = _min_manhattan_distance_to_buildings(pos, building_positions)
		if min_distance > threshold:
			element_grid.remove_element(pos)

func _min_manhattan_distance_to_buildings(pos: Vector2i, building_positions: Array[Vector2i]) -> int:
	var min_dist := -1
	for bp: Vector2i in building_positions:
		var dist := absi(pos.x - bp.x) + absi(pos.y - bp.y)
		if min_dist == -1 or dist < min_dist:
			min_dist = dist
	return min_dist