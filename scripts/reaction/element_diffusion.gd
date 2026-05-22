class_name ElementDiffusion
extends Node

const DIR_UP: Vector2i = Vector2i(0, -1)
const DIR_DOWN: Vector2i = Vector2i(0, 1)
const DIR_LEFT: Vector2i = Vector2i(-1, 0)
const DIR_RIGHT: Vector2i = Vector2i(1, 0)

func diffuse_all(element_grid: ElementGrid, steps: int) -> void:
	for _i in range(steps):
		_diffuse_single_step(element_grid)

func _diffuse_single_step(element_grid: ElementGrid) -> void:
	var positions: Array[Vector2i] = element_grid.get_all_element_positions()
	positions.shuffle()

	for pos: Vector2i in positions:
		var element: ElementData = element_grid.get_element(pos)
		if element == null:
			continue

		var directions: Array[Dictionary] = _get_weighted_directions(element.element_type)
		if directions.is_empty():
			continue

		var target_dir: Vector2i = _weighted_random(directions)
		var target_pos: Vector2i = pos + target_dir

		if element_grid.is_position_available(target_pos):
			element_grid.set_element(target_pos, element)
			element_grid.remove_element(pos)

func _get_weighted_directions(element_type: ElementTypeData) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []

	if element_type.diffusion_rate == 0.0:
		return choices

	if element_type.gravity > 0:
		var weight: float = element_type.gravity * (1.0 - element_type.diffusion_rate)
		choices.append({"dir": DIR_DOWN, "weight": weight})
	elif element_type.gravity < 0:
		var weight: float = abs(element_type.gravity) * (1.0 - element_type.diffusion_rate)
		choices.append({"dir": DIR_UP, "weight": weight})

	var lateral_weight: float = (1.0 - abs(element_type.gravity)) * element_type.lateral_priority * element_type.diffusion_rate
	if lateral_weight > 0.0:
		choices.append({"dir": DIR_LEFT, "weight": lateral_weight})
		choices.append({"dir": DIR_RIGHT, "weight": lateral_weight})

	return choices

func _weighted_random(choices: Array[Dictionary]) -> Vector2i:
	var total_weight: float = 0.0
	for choice: Dictionary in choices:
		total_weight += choice["weight"]

	var roll: float = randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for choice: Dictionary in choices:
		cumulative += choice["weight"]
		if roll < cumulative:
			return choice["dir"]

	return choices.back()["dir"]
