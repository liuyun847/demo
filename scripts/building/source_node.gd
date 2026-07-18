class_name SourceNode
extends BuildingBase

var element_type_id: String = "water"

## 元素类型是否已确认。放置后等待用户选择，确认后才开始产出（由扩散系统接管）。
var _type_confirmed: bool = false

func set_element_type(type_id: String) -> void:
	element_type_id = type_id
	_type_confirmed = true
	queue_redraw()

func has_type_selected() -> bool:
	return _type_confirmed


func _draw() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var size := float(GameConfig.BUILDING_SIZE)

	var element_type := ElementRegistry.get_element_type(element_type_id)
	var elem_color: Color = element_type.color if element_type else Color.WHITE

	# 元素色填充表示产出的元素类型
	draw_rect(Rect2(-half, -half, size, size), Color(elem_color, 0.7))
	# 中心圆点（比 collector 小，区分"产出源"）
	draw_circle(Vector2.ZERO, half * 0.25, Color.WHITE)
	draw_circle(Vector2.ZERO, half * 0.25, Color(elem_color, GameConfig.ELEMENT_ALPHA))
	# 边框
	draw_rect(Rect2(-half, -half, size, size), Color(0.25, 0.25, 0.25), false, 1.5)

func get_building_name() -> String:
	var type_data := ElementRegistry.get_element_type(element_type_id)
	if type_data:
		return "源头(%s)" % type_data.display_name
	return "源头(未知)"

func get_tooltip_summary() -> Dictionary:
	return {
		"name": get_building_name(),
		"type": "A 型 - 源头",
		"cost": "%.1f 源质/tick" % GameConfig.SOURCE_ESSENCE_COST_PER_TICK,
	}

func get_tooltip_details() -> Dictionary:
	var type_data := ElementRegistry.get_element_type(element_type_id)
	var type_name: String = type_data.display_name if type_data else "未知"
	return {
		"元素类型": type_name,
		"消耗": "%.1f 源质/tick" % GameConfig.SOURCE_ESSENCE_COST_PER_TICK,
	}
