class_name CollectorNode
extends BuildingBase

var collection_radius: int = GameConfig.collector_default_radius

func try_collect(element_grid: ElementGrid) -> float:
	var total_essence: float = 0.0
	var cells_to_collect: Array[Vector2i] = []

	for dx in range(-collection_radius, collection_radius + 1):
		for dy in range(-collection_radius, collection_radius + 1):
			if dx == 0 and dy == 0:
				continue
			var check_pos: Vector2i = grid_position + Vector2i(dx, dy)
			var element: ElementData = element_grid.get_element(check_pos)
			if element == null:
				continue
			if element_grid.is_building_at(check_pos):
				continue
			var value: float = ElementRegistry.calculate_value(element.element_type, element.complexity)
			total_essence += value
			cells_to_collect.append(check_pos)

	for pos: Vector2i in cells_to_collect:
		element_grid.remove_element(pos)

	return total_essence

func get_building_name() -> String:
	return "收集器"

func get_tooltip_summary() -> Dictionary:
	return {
		"name": get_building_name(),
		"type": "B 型 - 收集器",
		"radius": "半径 %d" % collection_radius,
	}

func get_tooltip_details() -> Dictionary:
	return {
		"收集半径": collection_radius,
	}
