class_name PipeNode
extends FluidNodeBase

var connection_mask: int = 0:
	set(value):
		connection_mask = value
		queue_redraw()

var network_state: int = 0:
	set(value):
		if network_state != value:
			network_state = value
			queue_redraw()

func _ready() -> void:
	add_to_group("pipe")

func refresh_connections() -> void:
	var bm := get_parent() as BuildingManager
	if bm == null:
		return

	var my_pos := grid_position
	var mask := 0

	if _is_connectable_at(bm, my_pos + Vector2i(0, -1)):
		mask |= GridCoordinate.DirFlag.UP
	if _is_connectable_at(bm, my_pos + Vector2i(1, 0)):
		mask |= GridCoordinate.DirFlag.RIGHT
	if _is_connectable_at(bm, my_pos + Vector2i(0, 1)):
		mask |= GridCoordinate.DirFlag.DOWN
	if _is_connectable_at(bm, my_pos + Vector2i(-1, 0)):
		mask |= GridCoordinate.DirFlag.LEFT

	connection_mask = mask

func _is_connectable_at(bm: Node, grid_pos: Vector2i) -> bool:
	var building_manager := bm as BuildingManager
	if not building_manager or not building_manager.buildings.has(grid_pos):
		return false
	var building_data: BuildingData = building_manager.buildings[grid_pos] as BuildingData
	if not building_data:
		return false
	return BuildingData.is_fluid_building(building_data.building_type)

func get_pressure() -> float:
	return 0.0


func get_building_name() -> String:
	return "管道"

func get_tooltip_summary() -> Dictionary:
	var state_text := "未连通"
	if network_state == 1:
		state_text = "输送中"
	elif network_state == 2:
		state_text = "已满载"
	return {"网络状态": state_text}

func get_tooltip_details() -> Dictionary:
	var connections: Array[String] = []
	if connection_mask & GridCoordinate.DirFlag.UP:
		connections.append("上")
	if connection_mask & GridCoordinate.DirFlag.DOWN:
		connections.append("下")
	if connection_mask & GridCoordinate.DirFlag.LEFT:
		connections.append("左")
	if connection_mask & GridCoordinate.DirFlag.RIGHT:
		connections.append("右")
	var conn_str := "无" if connections.is_empty() else "、".join(connections)
	return {
		"连接方向": conn_str,
	}

func _draw() -> void:
	var half := GameConfig.building_size / 2.0

	var color_bg: Color
	var color_passage: Color

	if network_state == 0:
		color_bg = Color(0.12, 0.12, 0.12)
		color_passage = Color(0.35, 0.35, 0.35)
	elif network_state == 1:
		color_bg = Color(0.12, 0.18, 0.25)
		color_passage = Color(0.3, 0.75, 1.0)
	else:
		color_bg = Color(0.10, 0.20, 0.10)
		color_passage = Color(0.2, 0.85, 0.2)

	var wall_w := 2.5
	var color_wall := Color(0.25, 0.25, 0.25)
	var passage_w := 14.0
	var pw := passage_w / 2.0

	draw_rect(Rect2(-half, -half, GameConfig.building_size, GameConfig.building_size), color_bg)

	if connection_mask & GridCoordinate.DirFlag.LEFT:
		draw_rect(Rect2(-half, -pw, half, passage_w), color_passage)
	if connection_mask & GridCoordinate.DirFlag.RIGHT:
		draw_rect(Rect2(0, -pw, half, passage_w), color_passage)
	if connection_mask & GridCoordinate.DirFlag.UP:
		draw_rect(Rect2(-pw, -half, passage_w, half), color_passage)
	if connection_mask & GridCoordinate.DirFlag.DOWN:
		draw_rect(Rect2(-pw, 0, passage_w, half), color_passage)

	if connection_mask != 0:
		draw_rect(Rect2(-pw, -pw, passage_w, passage_w), color_passage)

	draw_rect(Rect2(-half, -half, GameConfig.building_size, GameConfig.building_size), color_wall, false, wall_w)

	if connection_mask & GridCoordinate.DirFlag.LEFT:
		draw_rect(Rect2(-half, -pw, wall_w, passage_w), color_passage)
	if connection_mask & GridCoordinate.DirFlag.RIGHT:
		draw_rect(Rect2(half - wall_w, -pw, wall_w, passage_w), color_passage)
	if connection_mask & GridCoordinate.DirFlag.UP:
		draw_rect(Rect2(-pw, -half, passage_w, wall_w), color_passage)
	if connection_mask & GridCoordinate.DirFlag.DOWN:
		draw_rect(Rect2(-pw, half - wall_w, passage_w, wall_w), color_passage)
