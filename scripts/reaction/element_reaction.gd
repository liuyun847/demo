class_name ElementReaction
extends Node

const DIR_4: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

func process_all(element_grid: ElementGrid, registry: Node) -> void:
	var positions: Array[Vector2i] = element_grid.get_all_element_positions()

	for pos: Vector2i in positions:
		_check_reaction(pos, element_grid, registry)

func _check_reaction(pos: Vector2i, grid: ElementGrid, registry: Node) -> bool:
	var current_element: ElementData = grid.get_element(pos)
	if current_element == null:
		return false

	for neighbor_offset: Vector2i in DIR_4:
		var neighbor_pos: Vector2i = pos + neighbor_offset
		var neighbor_element: ElementData = grid.get_element(neighbor_pos)
		if neighbor_element == null:
			continue

		var product_id: String = registry.get_reaction(
			current_element.element_type.element_id,
			neighbor_element.element_type.element_id
		)
		if product_id.is_empty():
			continue

		var product_type: ElementTypeData = registry.get_element_type(product_id)
		if product_type == null:
			continue

		var new_complexity: int = registry.calculate_complexity(
			current_element.complexity,
			neighbor_element.complexity
		)

		var new_element := ElementData.new()
		new_element.element_type = product_type
		new_element.complexity = new_complexity

		grid.remove_element(neighbor_pos)
		grid.remove_element(pos)
		grid.set_element(pos, new_element)

		EventBus.reaction_occurred.emit(
			pos,
			current_element.element_type.element_id,
			neighbor_element.element_type.element_id,
			product_id
		)

		return true

	return false
