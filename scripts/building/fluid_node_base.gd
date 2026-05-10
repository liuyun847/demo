class_name FluidNodeBase
extends Node2D

@export var grid_position: Vector2i

func get_pressure() -> float:
	push_error("必须由子类实现")
	return 0.0

func collect_transfers(_transfers: Array[Dictionary]) -> void:
	pass

func _get_available_fluid() -> int:
	return 0

func _can_transfer_to_direction(_dir_idx: int, _neighbor_pos: Vector2i) -> bool:
	return true

func _get_source_pressure() -> float:
	return get_pressure()

func _get_transfer_capacity_base(_neighbor: Node) -> int:
	return 0

func _get_neighbor_node(bm: Node, grid_pos: Vector2i) -> Node:
	var node_name := "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	return bm.get_node_or_null(node_name)

func _collect_fluid_transfers(transfers: Array[Dictionary]) -> void:
	var available := _get_available_fluid()
	if available <= 0:
		return

	var bm := get_parent()
	if bm == null or not bm.has_method("has_building"):
		return

	for dir_idx in 4:
		if available <= 0:
			break

		var neighbor_pos: Vector2i = grid_position + GridCoordinate.DIR_4[dir_idx]
		if not _can_transfer_to_direction(dir_idx, neighbor_pos):
			continue

		var neighbor := _get_neighbor_node(bm, neighbor_pos)
		if not neighbor or not neighbor.has_method("get_pressure"):
			continue
		if not ("max_capacity" in neighbor and "capacity" in neighbor):
			continue

		var diff: float = _get_source_pressure() - neighbor.get_pressure()
		if diff <= GameConfig.fluid_pressure_threshold:
			continue

		var amount := int(diff * GameConfig.fluid_flow_rate * float(_get_transfer_capacity_base(neighbor)))
		amount = mini(amount, available)
		amount = mini(amount, neighbor.max_capacity - neighbor.capacity)
		if amount == 0 and available > 0 and neighbor.max_capacity > neighbor.capacity:
			amount = 1

		if amount > 0:
			transfers.append({
				"src": self,
				"dst": neighbor,
				"amount": amount,
			})
			available -= amount

func get_building_name() -> String:
	return "未知建筑"

func get_tooltip_summary() -> Dictionary:
	return {}

func get_tooltip_details() -> Dictionary:
	return {}
