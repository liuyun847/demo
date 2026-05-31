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
			if not element_grid.has_fluid(check_pos):
				continue
			if element_grid.is_building_at(check_pos):
				continue
			total_essence += 1.0
			cells_to_collect.append(check_pos)

	for pos: Vector2i in cells_to_collect:
		element_grid.remove_fluid(pos)

	return total_essence

func _draw() -> void:
	var half := GameConfig.building_size / 2.0
	var size := float(GameConfig.building_size)

	var color_bg := Color(0.4, 0.2, 0.7)
	var color_inner := Color(0.55, 0.3, 0.85)

	var inset := 4.0
	var diamond := PackedVector2Array([
		Vector2(0, -half + inset),
		Vector2(half - inset, 0),
		Vector2(0, half - inset),
		Vector2(-half + inset, 0),
	])
	draw_colored_polygon(diamond, color_bg)

	var inner_inset := inset + 6.0
	var inner_diamond := PackedVector2Array([
		Vector2(0, -half + inner_inset),
		Vector2(half - inner_inset, 0),
		Vector2(0, half - inner_inset),
		Vector2(-half + inner_inset, 0),
	])
	draw_colored_polygon(inner_diamond, color_inner)

	var center := Vector2.ZERO
	var circle_radius := half * 0.2
	draw_circle(center, circle_radius, Color.WHITE)

	draw_rect(Rect2(-half, -half, size, size), Color(0.25, 0.25, 0.25), false, 1.5)

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
