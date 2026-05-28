class_name EmitterNode
extends BuildingBase

var element_type_id: String = "water"
var output_direction: Vector2i = Vector2i(0, 1)
var essence_cost_per_tick: float = GameConfig.emitter_essence_cost_per_tick
var _blocked_ticks: int = 0

func is_blocked() -> bool:
	return _blocked_ticks > 0

func set_element_type(type_id: String) -> void:
	element_type_id = type_id
	queue_redraw()

func set_output_direction(dir: Vector2i) -> void:
	output_direction = dir
	queue_redraw()

func has_type_selected() -> bool:
	return true

func try_output(element_grid: ElementGrid) -> bool:
	if not has_type_selected():
		return false

	if _blocked_ticks > 0:
		_blocked_ticks -= 1
		return false

	var target_pos: Vector2i = grid_position + output_direction
	if not element_grid.is_position_available(target_pos):
		_blocked_ticks = GameConfig.emitter_blocked_cooldown
		return false

	_blocked_ticks = 0

	var element_type: ElementTypeData = ElementRegistry.get_element_type(element_type_id)
	if element_type == null:
		return false

	var element := ElementData.new()
	element.element_type = element_type
	element.complexity = 1
	element.source_y = grid_position.y

	return element_grid.set_element(target_pos, element)

func _draw() -> void:
	var half := GameConfig.building_size / 2.0
	var size := float(GameConfig.building_size)

	var element_type := ElementRegistry.get_element_type(element_type_id)
	var elem_color: Color = element_type.color if element_type else Color.WHITE

	draw_rect(Rect2(-half, -half, size, size), Color(elem_color, 0.7))

	var dir := output_direction
	if dir == Vector2i.ZERO:
		dir = get_default_direction()

	var arrow_size := half * 0.55
	var arrow_center := Vector2(dir) * arrow_size * 0.25
	var arrow_tip := arrow_center + Vector2(dir) * arrow_size * 0.55
	var perp := Vector2(-dir.y, dir.x)
	var arrow_left := arrow_center + perp * arrow_size * 0.35
	var arrow_right := arrow_center - perp * arrow_size * 0.35

	draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]), Color(elem_color, 0.85))

	draw_rect(Rect2(-half, -half, size, size), Color(0.25, 0.25, 0.25), false, 1.5)

func get_building_name() -> String:
	return "喷口(水)"

func get_default_direction() -> Vector2i:
	return Vector2i(0, 1)

func get_tooltip_summary() -> Dictionary:
	return {
		"name": get_building_name(),
		"type": "A 型 - 发射器",
		"cost": "%.1f 源质/tick" % essence_cost_per_tick,
	}

func get_tooltip_details() -> Dictionary:
	return {
		"元素类型": "水",
		"消耗": "%.1f 源质/tick" % essence_cost_per_tick,
		"方向": "上" if output_direction == Vector2i(0, -1) else "下" if output_direction == Vector2i(0, 1) else "左" if output_direction == Vector2i(-1, 0) else "右",
	}
