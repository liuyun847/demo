class_name BuildingManager
extends Node2D

var buildings: Dictionary = {}  # key: Vector2i, value: BuildingData

@onready var building_texture: Texture2D = preload("res://resources/building_default.svg")

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func place_building(grid_pos: Vector2i, building_type: String = "default") -> bool:
	if has_building(grid_pos):
		return false

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	# 创建视觉表现（使用 SVG 贴图）
	var visual := Sprite2D.new()
	visual.texture = building_texture
	visual.name = "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	var half_size := GameConfig.building_size / 2.0
	visual.scale = Vector2.ONE * (float(GameConfig.building_size) / building_texture.get_width())
	visual.global_position = Vector2(
		grid_pos.x * GameConfig.cell_size + GameConfig.building_border + half_size,
		grid_pos.y * GameConfig.cell_size + GameConfig.building_border + half_size
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
