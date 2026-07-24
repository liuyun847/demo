class_name CollectorNode
extends BuildingBase

var collection_radius: int = GameConfig.COLLECTOR_DEFAULT_RADIUS
## 筛选元素类型：空 = 收全部（默认，兼容旧存档）
var filter_element_type: String = ""

func set_filter(type_id: String) -> void:
	filter_element_type = type_id
	queue_redraw()

func try_collect(element_grid: ElementGrid) -> float:
	var total_essence: float = 0.0
	var cells_to_collect: Array[Vector2i] = []

	for dx in range(-collection_radius, collection_radius + 1):
		for dy in range(-collection_radius, collection_radius + 1):
			if dx == 0 and dy == 0:
				continue
			var check_pos: Vector2i = grid_position + Vector2i(dx, dy)
			if not element_grid.has_element(check_pos):
				continue
			if element_grid.is_building_at(check_pos):
				continue
			# 跳过反应产物存续期内的元素（至少存活 1 tick 可见）
			if element_grid.is_product(check_pos):
				continue
			# 按筛选元素类型过滤：空筛选收全部
			var element_id: String = element_grid.get_element_id(check_pos)
			if not filter_element_type.is_empty() and element_id != filter_element_type:
				continue
			# 按元素类型的 collect_value 计算价值
			var type_data: ElementTypeData = ElementRegistry.get_element_type(element_id)
			var value: float = type_data.collect_value if type_data else 1.0
			total_essence += value
			cells_to_collect.append(check_pos)

	for pos: Vector2i in cells_to_collect:
		element_grid.remove_element(pos)

	return total_essence

func _draw() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var size := float(GameConfig.BUILDING_SIZE)

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

	# 中心圆点颜色：有筛选时用筛选元素色，无筛选保持白色
	var center_color: Color = Color.WHITE
	if not filter_element_type.is_empty():
		var ft := ElementRegistry.get_element_type(filter_element_type)
		if ft:
			center_color = ft.color
	draw_circle(Vector2.ZERO, half * 0.2, center_color)

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
	var filter_name: String = "全部"
	if not filter_element_type.is_empty():
		var ft := ElementRegistry.get_element_type(filter_element_type)
		filter_name = ft.display_name if ft else filter_element_type
	return {
		"收集半径": collection_radius,
		"筛选": filter_name,
	}
