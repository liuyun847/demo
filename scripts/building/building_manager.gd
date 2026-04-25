class_name BuildingManager
extends Node2D

var buildings: Dictionary = {}  # key: Vector2i, value: BuildingData

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func place_building(grid_pos: Vector2i, building_type: String = "default") -> bool:
	if has_building(grid_pos):
		return false

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	# 创建视觉表现（ColorRect 占位符，后续可替换为实际建筑场景）
	var visual := ColorRect.new()
	visual.size = Vector2(GameConfig.building_size, GameConfig.building_size)
	visual.color = GameConfig.building_default_color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.name = "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	visual.global_position = Vector2(
		grid_pos.x * GameConfig.cell_size + GameConfig.building_border,
		grid_pos.y * GameConfig.cell_size + GameConfig.building_border
	)
	add_child(visual)

	buildings[grid_pos] = data
	EventBus.building_placed.emit(grid_pos)
	return true

func remove_building(grid_pos: Vector2i) -> bool:
	if not has_building(grid_pos):
		return false

	var node_name := "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	var visual := get_node_or_null(node_name)
	if visual:
		visual.queue_free()

	buildings.erase(grid_pos)
	EventBus.building_removed.emit(grid_pos)
	return true

func get_all_buildings_data() -> Dictionary:
	return buildings.duplicate()

func clear_all_buildings() -> void:
	for grid_pos in buildings.keys():
		remove_building(grid_pos)
