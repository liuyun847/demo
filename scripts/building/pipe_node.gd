class_name PipeNode
extends FluidNodeBase

enum ConnectionDir {
	TOP = 1,
	RIGHT = 2,
	BOTTOM = 4,
	LEFT = 8,
}

@export var capacity: int = 0:
	set(value):
		capacity = clampi(value, 0, max_capacity)
		queue_redraw()

@export var max_capacity: int = 5:
	set(value):
		max_capacity = maxi(value, 1)
		capacity = mini(capacity, max_capacity)
		queue_redraw()

var connection_mask: int = 0:
	set(value):
		connection_mask = value
		queue_redraw()

func _ready() -> void:
	add_to_group("fluid_node")

func get_fill_ratio() -> float:
	return float(capacity) / float(max_capacity)

func get_pressure() -> float:
	return get_fill_ratio()

func collect_transfers(transfers: Array[Dictionary]) -> void:
	if capacity <= 0:
		return

	var bm := get_parent()
	if bm == null or not bm.has_method("has_building"):
		return

	var available := capacity

	for dir_idx in 4:
		if available <= 0:
			break
		if not (connection_mask & (1 << dir_idx)):
			continue

		var neighbor_pos: Vector2i = grid_position + GridCoordinate.DIR_4[dir_idx]
		var nname := "Building_%d_%d" % [neighbor_pos.x, neighbor_pos.y]
		var neighbor := bm.get_node_or_null(nname)
		if not neighbor or not neighbor.has_method("get_pressure"):
			continue

		var diff: float = get_pressure() - neighbor.get_pressure()
		if diff <= GameConfig.fluid_pressure_threshold:
			continue

		var amount := int(diff * GameConfig.fluid_flow_rate * float(max_capacity))
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

func add(amount: int) -> int:
	var old := capacity
	capacity = clampi(capacity + amount, 0, max_capacity)
	return capacity - old

func remove(amount: int) -> int:
	var old := capacity
	capacity = clampi(capacity - amount, 0, max_capacity)
	return old - capacity

func refresh_connections() -> void:
	var bm := get_parent()
	if bm == null or not bm.has_method("has_building"):
		return

	var my_pos := grid_position
	var mask := 0

	if _is_connectable_at(bm, my_pos + Vector2i(0, -1)):
		mask |= ConnectionDir.TOP
	if _is_connectable_at(bm, my_pos + Vector2i(1, 0)):
		mask |= ConnectionDir.RIGHT
	if _is_connectable_at(bm, my_pos + Vector2i(0, 1)):
		mask |= ConnectionDir.BOTTOM
	if _is_connectable_at(bm, my_pos + Vector2i(-1, 0)):
		mask |= ConnectionDir.LEFT

	connection_mask = mask

func _is_connectable_at(bm: Node, grid_pos: Vector2i) -> bool:
	var building_manager := bm as BuildingManager
	if not building_manager or not building_manager.buildings.has(grid_pos):
		return false
	var building_data: BuildingData = building_manager.buildings[grid_pos] as BuildingData
	if not building_data:
		return false
	return BuildingData.has_capacity(building_data.building_type)

func get_building_name() -> String:
	return "管道"

func get_tooltip_summary() -> Dictionary:
	return {
		"容量": "%d / %d" % [capacity, max_capacity],
	}

func get_tooltip_details() -> Dictionary:
	var connections: Array[String] = []
	if connection_mask & ConnectionDir.TOP:
		connections.append("上")
	if connection_mask & ConnectionDir.BOTTOM:
		connections.append("下")
	if connection_mask & ConnectionDir.LEFT:
		connections.append("左")
	if connection_mask & ConnectionDir.RIGHT:
		connections.append("右")
	var conn_str := "无" if connections.is_empty() else "、".join(connections)
	return {
		"填充率": "%d%%" % int(get_fill_ratio() * 100.0),
		"压力": "%.2f" % get_pressure(),
		"连接方向": conn_str,
	}

func _draw() -> void:
	var half := GameConfig.building_size / 2.0
	var wall_w := 2.5

	var color_bg := Color(0.12, 0.12, 0.12)
	var color_wall := Color(0.25, 0.25, 0.25)

	var fill_ratio := get_fill_ratio()
	var color_empty := Color(0.38, 0.38, 0.38)
	var color_full := Color(1.0, 1.0, 1.0)
	var color_passage := color_empty.lerp(color_full, fill_ratio)

	var passage_w := 14.0
	var pw := passage_w / 2.0

	draw_rect(Rect2(-half, -half, GameConfig.building_size, GameConfig.building_size), color_bg)

	var hw := passage_w / 2.0

	if connection_mask & ConnectionDir.LEFT:
		draw_rect(Rect2(-half, -hw, half, passage_w), color_passage)
	if connection_mask & ConnectionDir.RIGHT:
		draw_rect(Rect2(0, -hw, half, passage_w), color_passage)
	if connection_mask & ConnectionDir.TOP:
		draw_rect(Rect2(-hw, -half, passage_w, half), color_passage)
	if connection_mask & ConnectionDir.BOTTOM:
		draw_rect(Rect2(-hw, 0, passage_w, half), color_passage)

	if connection_mask != 0:
		draw_rect(Rect2(-hw, -hw, passage_w, passage_w), color_passage)

	draw_rect(Rect2(-half, -half, GameConfig.building_size, GameConfig.building_size), color_wall, false, wall_w)

	if connection_mask & ConnectionDir.LEFT:
		draw_rect(Rect2(-half, -pw, wall_w, passage_w), color_passage)
	if connection_mask & ConnectionDir.RIGHT:
		draw_rect(Rect2(half - wall_w, -pw, wall_w, passage_w), color_passage)
	if connection_mask & ConnectionDir.TOP:
		draw_rect(Rect2(-pw, -half, passage_w, wall_w), color_passage)
	if connection_mask & ConnectionDir.BOTTOM:
		draw_rect(Rect2(-pw, half - wall_w, passage_w, wall_w), color_passage)
