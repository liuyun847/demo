class_name WaterSourceNode
extends FluidNodeBase

var output_per_tick: int = 30
var remaining_output: int = 0

var capacity: int = 0
var max_capacity: int = 0

func _ready() -> void:
	add_to_group("fluid_node")

func get_pressure() -> float:
	return 1.0

func collect_transfers(transfers: Array[Dictionary]) -> void:
	if remaining_output <= 0:
		return

	var bm := get_parent()
	if bm == null or not bm.has_method("has_building"):
		return

	var available := remaining_output

	# 水源作为特殊节点，直接向四邻居推水（不受连接掩码约束）
	var neighbors := [
		grid_position + Vector2i(0, -1),
		grid_position + Vector2i(1, 0),
		grid_position + Vector2i(0, 1),
		grid_position + Vector2i(-1, 0),
	]

	for npos in neighbors:
		if available <= 0:
			break
		if not bm.has_building(npos):
			continue

		var nname := "Building_%d_%d" % [npos.x, npos.y]
		var neighbor := bm.get_node_or_null(nname)
		if not neighbor or not neighbor.has_method("get_pressure"):
			continue

		var diff: float = 1.0 - neighbor.get_pressure()
		if diff <= GameConfig.fluid_pressure_threshold:
			continue

		var amount := int(diff * GameConfig.fluid_flow_rate * float(neighbor.max_capacity))
		amount = mini(amount, available)
		amount = mini(amount, neighbor.max_capacity - neighbor.capacity)
		if amount == 0 and available > 0 and neighbor.max_capacity > neighbor.capacity:
			amount = 1

		if amount > 0:
			transfers.append({
				"src": self ,
				"dst": neighbor,
				"amount": amount,
			})
			available -= amount


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
