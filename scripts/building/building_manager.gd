class_name BuildingManager
extends Node2D

var buildings: Dictionary = {} # key: Vector2i, value: BuildingData
var ghost_cells: Array[Vector2i] = []
var remove_ghost_cells: Array[Vector2i] = []
var selected_cells: Array[Vector2i] = []
var paste_ghost_cells: Array[Vector2i] = []
var paste_ghost_types: Dictionary = {}
var select_ghost_cells: Array[Vector2i] = []
var deselect_ghost_cells: Array[Vector2i] = []

@onready var building_texture: Texture2D = preload("res://resources/building_default.svg")

const _WaterSourceScript = preload("res://scripts/building/water_source_node.gd")

func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)
	_init_fluid_coordinator()

func _init_fluid_coordinator() -> void:
	var coordinator := FluidCoordinator.new()
	coordinator.name = "FluidCoordinator"
	add_child(coordinator)

func _on_selection_changed(cells: Array[Vector2i]) -> void:
	set_selected_cells(cells)

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func _get_building_texture(building_type: String) -> Texture2D:
	if building_type == "default":
		return building_texture
	if building_type.begins_with("type_"):
		var tex_path := "res://resources/buildings/building_%s.svg" % building_type.substr(5)
		if ResourceLoader.exists(tex_path):
			return load(tex_path)
	return building_texture

func place_building(grid_pos: Vector2i, building_type: String = "default") -> bool:
	if has_building(grid_pos):
		return false

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	var node_name := "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	var world_pos := GridCoordinate.grid_to_world(grid_pos)

	if building_type == GameConfig.container_type_id:
		var container := ContainerNode.new()
		container.name = node_name
		container.global_position = world_pos
		container.grid_position = grid_pos
		container.capacity = data.capacity
		container.max_capacity = data.max_capacity
		add_child(container)
	elif building_type == GameConfig.pipe_type_id:
		var pipe := PipeNode.new()
		pipe.name = node_name
		pipe.global_position = world_pos
		pipe.grid_position = grid_pos
		pipe.capacity = data.capacity
		pipe.max_capacity = data.max_capacity
		add_child(pipe)
	elif building_type == GameConfig.water_source_type_id:
		var source = _WaterSourceScript.new()
		source.name = node_name
		source.global_position = world_pos
		source.grid_position = grid_pos
		add_child(source)
	else:
		var visual := Sprite2D.new()
		var type_texture := _get_building_texture(building_type)
		visual.texture = type_texture
		visual.name = node_name
		var tex_width := type_texture.get_width()
		if tex_width > 0:
			visual.scale = Vector2.ONE * (float(GameConfig.building_size) / tex_width)
		else:
			visual.scale = Vector2.ONE
		visual.global_position = world_pos
		add_child(visual)

	buildings[grid_pos] = data
	EventBus.building_placed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
	return true

func remove_building(grid_pos: Vector2i) -> bool:
	if not has_building(grid_pos):
		return false

	var node_name := "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	var node := get_node_or_null(node_name)
	if node is ContainerNode or node is PipeNode:
		var data: BuildingData = buildings[grid_pos]
		data.capacity = node.capacity
		data.max_capacity = node.max_capacity
		node.queue_free()
	elif node:
		node.queue_free()

	buildings.erase(grid_pos)
	EventBus.building_removed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
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

func set_selected_cells(cells: Array[Vector2i]) -> void:
	selected_cells = cells
	queue_redraw()

func set_paste_preview(anchor: Vector2i, clipboard: Dictionary) -> void:
	paste_ghost_cells.clear()
	paste_ghost_types.clear()
	if clipboard.is_empty() or not clipboard.has("buildings"):
		queue_redraw()
		return
	var clip_buildings: Array[Dictionary] = clipboard["buildings"]
	for item in clip_buildings:
		var grid_pos: Vector2i = anchor + item["offset"]
		var building_type: String = item["type"]
		paste_ghost_cells.append(grid_pos)
		paste_ghost_types[grid_pos] = building_type
	queue_redraw()

func clear_paste_preview() -> void:
	paste_ghost_cells.clear()
	paste_ghost_types.clear()
	queue_redraw()

func show_select_ghost(cells: Array[Vector2i]) -> void:
	select_ghost_cells = cells
	queue_redraw()

func hide_select_ghost() -> void:
	select_ghost_cells.clear()
	queue_redraw()

func show_deselect_ghost(cells: Array[Vector2i]) -> void:
	deselect_ghost_cells = cells
	queue_redraw()

func hide_deselect_ghost() -> void:
	deselect_ghost_cells.clear()
	queue_redraw()

func get_buildings_in_cells(cells: Array[Vector2i]) -> Dictionary:
	var result := {}
	for grid_pos: Vector2i in cells:
		if has_building(grid_pos):
			var data: BuildingData = buildings[grid_pos]
			result[grid_pos] = data.building_type
	return result

func _get_building_color(building_type: String) -> Color:
	if building_type == "default":
		return GameConfig.building_default_color
	if building_type.begins_with("type_"):
		var idx := building_type.substr(5).to_int()
		if idx >= 1 and idx <= 10:
			return Color.from_hsv(float(idx - 1) / 10.0, 0.7, 0.9)
	return GameConfig.building_default_color

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

	if not select_ghost_cells.is_empty():
		var cell_size := GameConfig.cell_size
		var half_cell := cell_size / 2.0
		var fill := GameConfig.selection_highlight_color
		var border := GameConfig.selection_border_color
		for grid_pos in select_ghost_cells:
			var world_pos := GridCoordinate.grid_to_world(grid_pos)
			var rect := Rect2(world_pos - Vector2(half_cell, half_cell), Vector2(cell_size, cell_size))
			draw_rect(rect, fill, true)
			draw_rect(rect, border, false, 2.0)

	if not deselect_ghost_cells.is_empty():
		var cell_size := GameConfig.cell_size
		var half_cell := cell_size / 2.0
		var fill := Color(0.6, 0.2, 0.2, 0.3)
		var border := Color(0.6, 0.2, 0.2, 0.8)
		for grid_pos in deselect_ghost_cells:
			var world_pos := GridCoordinate.grid_to_world(grid_pos)
			var rect := Rect2(world_pos - Vector2(half_cell, half_cell), Vector2(cell_size, cell_size))
			draw_rect(rect, fill, true)
			draw_rect(rect, border, false, 2.0)

	if not selected_cells.is_empty():
		var cell_size := GameConfig.cell_size
		var half_cell := cell_size / 2.0
		var fill := GameConfig.selection_highlight_color
		var border := GameConfig.selection_border_color
		for grid_pos in selected_cells:
			var world_pos := GridCoordinate.grid_to_world(grid_pos)
			var rect := Rect2(world_pos - Vector2(half_cell, half_cell), Vector2(cell_size, cell_size))
			draw_rect(rect, fill, true)
			draw_rect(rect, border, false, 2.0)

	if not paste_ghost_cells.is_empty():
		var building_size := GameConfig.building_size
		var half_size := building_size / 2.0
		var alpha := GameConfig.paste_ghost_alpha
		for grid_pos in paste_ghost_cells:
			var world_pos := GridCoordinate.grid_to_world(grid_pos)
			var rect := Rect2(world_pos - Vector2(half_size, half_size), Vector2(building_size, building_size))
			var building_type: String = paste_ghost_types.get(grid_pos, "default")
			var color := _get_building_color(building_type)
			color.a = alpha
			draw_rect(rect, color, true)
			var border_color := color
			border_color.a = minf(alpha + 0.35, 1.0)
			draw_rect(rect, border_color, false, 2.0)

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

func _refresh_pipe_connections(grid_pos: Vector2i) -> void:
	var neighbors := [
		grid_pos + Vector2i(0, -1),
		grid_pos + Vector2i(1, 0),
		grid_pos + Vector2i(0, 1),
		grid_pos + Vector2i(-1, 0)
	]
	for npos in neighbors:
		if has_building(npos):
			var node_name := "Building_%d_%d" % [npos.x, npos.y]
			var node := get_node_or_null(node_name)
			if node is PipeNode:
				node.refresh_connections()

	var self_node_name := "Building_%d_%d" % [grid_pos.x, grid_pos.y]
	var self_node := get_node_or_null(self_node_name)
	if self_node is PipeNode:
		self_node.refresh_connections()
