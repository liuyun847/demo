class_name ElementDiffusion
extends Node

const DIR_UP: Vector2i = Vector2i(0, -1)
const DIR_DOWN: Vector2i = Vector2i(0, 1)
const DIR_LEFT: Vector2i = Vector2i(-1, 0)
const DIR_RIGHT: Vector2i = Vector2i(1, 0)
const DIR_UP_LEFT: Vector2i = Vector2i(-1, -1)
const DIR_UP_RIGHT: Vector2i = Vector2i(1, -1)
const DIR_DOWN_LEFT: Vector2i = Vector2i(-1, 1)
const DIR_DOWN_RIGHT: Vector2i = Vector2i(1, 1)

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

	var new_placements: Dictionary = {}

	for pos: Vector2i in current_positions:
		var element: ElementData = element_grid.get_element(pos)
		if element == null:
			continue

		var directions := _get_spread_directions(element.element_type)

		for dir: Vector2i in directions:
			var target: Vector2i = pos + dir
			if target in new_placements:
				continue
			if not element_grid.is_position_available(target):
				continue

			var new_element := ElementData.new()
			new_element.element_type = element.element_type
			new_element.complexity = element.complexity
			new_placements[target] = new_element

	var new_cells: int = 0
	for target: Vector2i in new_placements:
		var data: ElementData = new_placements[target] as ElementData
		if element_grid.set_element(target, data):
			new_cells += 1

	return new_cells

func _get_spread_directions(element_type: ElementTypeData) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []

	if element_type.gravity > 0:
		dirs.append(DIR_DOWN)
		if element_type.diffusion_rate > 0:
			dirs.append(DIR_DOWN_LEFT)
			dirs.append(DIR_DOWN_RIGHT)
			dirs.append(DIR_LEFT)
			dirs.append(DIR_RIGHT)
	elif element_type.gravity < 0:
		dirs.append(DIR_UP)
		if element_type.diffusion_rate > 0:
			dirs.append(DIR_UP_LEFT)
			dirs.append(DIR_UP_RIGHT)
			dirs.append(DIR_LEFT)
			dirs.append(DIR_RIGHT)
	else:
		dirs = [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]

	return dirs

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