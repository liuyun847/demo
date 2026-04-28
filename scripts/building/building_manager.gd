class_name BuildingManager
extends Node2D

var buildings: Dictionary = {}  # key: Vector2i, value: BuildingData
var ghost_cells: Array[Vector2i] = []
var remove_ghost_cells: Array[Vector2i] = []

@onready var building_texture: Texture2D = preload("res://resources/building_default.svg")

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func place_building(grid_pos: Vector2i, building_type: String = "default") -> bool:
	if has_building(grid_pos):
		return false

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	var visual := Sprite2D.new()
	visual.texture = building_texture
	visual.name = "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	var tex_width := building_texture.get_width()
	if tex_width > 0:
		visual.scale = Vector2.ONE * (float(GameConfig.building_size) / tex_width)
	else:
		visual.scale = Vector2.ONE
	visual.global_position = GridCoordinate.grid_to_world(grid_pos)
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

func show_ghost(cells: Array[Vector2i]) -> void:
	ghost_cells = cells
	queue_redraw()

func hide_ghost() -> void:
	ghost_cells.clear()
	queue_redraw()

func show_remove_ghost(cells: Array[Vector2i]) -> void:
	remove_ghost_cells = cells
	queue_redraw()

func hide_remove_ghost() -> void:
	remove_ghost_cells.clear()
	queue_redraw()

func _draw() -> void:
	if not ghost_cells.is_empty():
		var building_size := GameConfig.building_size
		var half_size := building_size / 2.0
		var ghost_fill := Color(1, 1, 1, GameConfig.ghost_alpha)
		var ghost_border := Color.WHITE

		for grid_pos in ghost_cells:
			if has_building(grid_pos):
				continue
			var world_pos := GridCoordinate.grid_to_world(grid_pos)
			var rect := Rect2(world_pos - Vector2(half_size, half_size), Vector2(building_size, building_size))
			draw_rect(rect, ghost_fill, true)
			draw_rect(rect, ghost_border, false, 2.0)

	if not remove_ghost_cells.is_empty():
		var cell_size := GameConfig.cell_size
		var half_cell := cell_size / 2.0
		var remove_fill := Color(1, 0, 0, GameConfig.remove_ghost_alpha)
		var remove_border := Color.RED

		for grid_pos in remove_ghost_cells:
			var world_pos := GridCoordinate.grid_to_world(grid_pos)
			var rect := Rect2(world_pos - Vector2(half_cell, half_cell), Vector2(cell_size, cell_size))
			draw_rect(rect, remove_fill, true)
			draw_rect(rect, remove_border, false, 2.0)

static func get_line_cells(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dx := to_pos.x - from_pos.x
	var dy := to_pos.y - from_pos.y

	if abs(dx) >= abs(dy):
		var y := from_pos.y
		var start_x := mini(from_pos.x, to_pos.x)
		var end_x := maxi(from_pos.x, to_pos.x)
		for x in range(start_x, end_x + 1):
			cells.append(Vector2i(x, y))
	else:
		var x := from_pos.x
		var start_y := mini(from_pos.y, to_pos.y)
		var end_y := maxi(from_pos.y, to_pos.y)
		for y in range(start_y, end_y + 1):
			cells.append(Vector2i(x, y))

	return cells

func place_buildings_in_line(cells: Array[Vector2i], building_type: String = "default") -> int:
	var placed_count := 0
	for grid_pos in cells:
		if place_building(grid_pos, building_type):
			placed_count += 1
	return placed_count

static func get_rect_cells(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var min_x := mini(from_pos.x, to_pos.x)
	var max_x := maxi(from_pos.x, to_pos.x)
	var min_y := mini(from_pos.y, to_pos.y)
	var max_y := maxi(from_pos.y, to_pos.y)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			cells.append(Vector2i(x, y))

	return cells

func remove_buildings_in_rect(cells: Array[Vector2i]) -> int:
	var removed_count := 0
	for grid_pos in cells:
		if remove_building(grid_pos):
			removed_count += 1
	return removed_count
