class_name WaterSourceNode
extends FluidNodeBase

var output_per_tick: int = 30
var remaining_output: int = 0

func _ready() -> void:
	add_to_group("water_source")

func get_pressure() -> float:
	return 1.0


func get_building_name() -> String:
	return "水源"

func get_tooltip_summary() -> Dictionary:
	return {
		"每 tick 产出": str(output_per_tick),
	}

func get_tooltip_details() -> Dictionary:
	return {
		"压力": "1.0 (恒定)",
		"剩余待输出": str(remaining_output),
	}

func _draw() -> void:
	var half := GameConfig.building_size / 2.0

	var color_stone := Color(0.45, 0.38, 0.32)
	var color_stone_dark := Color(0.35, 0.28, 0.22)
	var color_water := Color(0.1, 0.5, 0.9)
	var color_water_light := Color(0.2, 0.65, 1.0)
	var color_highlight := Color(0.4, 0.8, 1.0, 0.3)

	var w := float(GameConfig.building_size)
	var wall_w := 5.0

	draw_rect(Rect2(-half, -half, w, w), color_stone)

	var inner_rect := Rect2(-half + wall_w, -half + wall_w * 0.5, w - wall_w * 2.0, w - wall_w * 1.5)
	draw_rect(inner_rect, color_water)

	var wave_y := inner_rect.position.y + inner_rect.size.y * 0.35
	var wave_w := inner_rect.size.x
	draw_rect(Rect2(inner_rect.position.x, wave_y, wave_w, 3.0), color_water_light)
	draw_rect(Rect2(inner_rect.position.x, wave_y + 6.0, wave_w, 2.0), color_highlight)

	var border := Rect2(-half, -half, w, w)
	draw_rect(border, color_stone_dark, false, 1.5)

	draw_rect(Rect2(-half, -half + 2.0, w, wall_w - 2.0), color_stone_dark)
