class_name CoreNode
extends BuildingBase

# 核心节点：占据地图中心 2x2 区域，不可删除/移动。
# 管道网络必须连通到核心才能激活（发射器/收集器才能工作）。

# 核心占据的四个格子（2x2 区域，从 -1,-1 到 0,0，以原点为中心）
const CORE_OCCUPIED_CELLS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(0, 0),
]

var _pulse_time: float = 0.0

func _ready() -> void:
	grid_position = Vector2i(0, 0)

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var half_size := GameConfig.building_size / 2.0
	# 2x2 核心的视觉缩放因子
	var visual_radius := half_size * 2.0
	var core_center := Vector2.ZERO

	# 外圈发光脉冲
	var pulse := (sin(_pulse_time * 2.0) * 0.5 + 0.5) * 0.3 + 0.7
	var glow_color := Color(0.2, 0.6, 1.0, pulse * 0.3)
	draw_circle(core_center, visual_radius * 1.1, glow_color)

	# 外圈菱形边框（以原点为中心，对称）
	var diamond_inset := 4.0
	var diamond_size := visual_radius - diamond_inset
	var diamond := PackedVector2Array([
		Vector2(0, -diamond_size),
		Vector2(diamond_size, 0),
		Vector2(0, diamond_size),
		Vector2(-diamond_size, 0),
	])
	draw_colored_polygon(diamond, Color(0.15, 0.4, 0.8, 0.6))
	# 分别绘制四条边，避免 closed 参数可能遗漏闭合段的问题
	var line_color := Color(0.3, 0.7, 1.0, 0.9)
	var line_width := 2.0
	draw_line(Vector2(0, -diamond_size), Vector2(diamond_size, 0), line_color, line_width)
	draw_line(Vector2(diamond_size, 0), Vector2(0, diamond_size), line_color, line_width)
	draw_line(Vector2(0, diamond_size), Vector2(-diamond_size, 0), line_color, line_width)
	draw_line(Vector2(-diamond_size, 0), Vector2(0, -diamond_size), line_color, line_width)

	# 内圈圆形
	var inner_radius := visual_radius * 0.3
	draw_circle(core_center, inner_radius, Color(0.2, 0.6, 1.0, 0.8))
	draw_circle(core_center, inner_radius * 0.6, Color(0.5, 0.85, 1.0, 0.9))

	# 中心光点
	draw_circle(core_center, inner_radius * 0.25, Color.WHITE)

	# 四个角的小装饰点（相对于原点对称）
	var corner_offset := visual_radius * 0.65
	var corners := [
		Vector2(-corner_offset, -corner_offset),
		Vector2(corner_offset, -corner_offset),
		Vector2(corner_offset, corner_offset),
		Vector2(-corner_offset, corner_offset),
	]
	for corner: Vector2 in corners:
		draw_circle(core_center + corner, 3.0, Color(0.3, 0.7, 1.0, 0.6))

	# 外边框
	var border_half := visual_radius
	draw_rect(Rect2(-border_half, -border_half, border_half * 2.0, border_half * 2.0), Color(0.3, 0.7, 1.0, 0.5), false, 2.0)

func get_building_name() -> String:
	return "核心"

func get_tooltip_summary() -> Dictionary:
	return {
		"name": get_building_name(),
		"type": "网络核心",
		"desc": "管道网络必须连通到核心才能激活",
	}

func get_tooltip_details() -> Dictionary:
	return {
		"说明": "地图中心的能量核心，连接管道网络",
		"状态": "不可删除",
		"范围": "2x2",
	}
