class_name BuildingManager
extends Node2D

var buildings: Dictionary[Vector2i, BuildingData] = {} # key: Vector2i, value: BuildingData
var _building_nodes: Dictionary[Vector2i, Node2D] = {} # key: Vector2i, value: Node2D
var fluid_pipes: Array[PipeNode] = []
var fluid_sources: Array[WaterSourceNode] = []
var ghost_cells: Array[Vector2i] = []
var remove_ghost_cells: Array[Vector2i] = []
var selected_cells: Array[Vector2i] = []
var paste_ghost_cells: Array[Vector2i] = []
var paste_ghost_types: Dictionary[Vector2i, String] = {}
var select_ghost_cells: Array[Vector2i] = []
var deselect_ghost_cells: Array[Vector2i] = []



func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)
	_init_fluid_coordinator()

func _init_fluid_coordinator() -> void:
	var coordinator: FluidCoordinator = preload("res://scripts/fluid/fluid_coordinator.gd").new()
	coordinator.name = "FluidCoordinator"
	add_child(coordinator)

func _on_selection_changed(cells: Array[Vector2i]) -> void:
	set_selected_cells(cells)

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func place_building(grid_pos: Vector2i, building_type: String = "default", restore_data: Dictionary = {}) -> bool:
	if has_building(grid_pos):
		return false

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	var node_name := get_building_node_name(grid_pos)
	var world_pos := GridCoordinate.grid_to_world(grid_pos)

	var building_node: Node2D

	if building_type == GameConfig.container_type_id:
		var container := ContainerNode.new()
		container.name = node_name
		container.global_position = world_pos
		container.grid_position = grid_pos
		add_child(container)
		building_node = container
		data.capacity = container.capacity
		data.max_capacity = container.max_capacity
	elif building_type == GameConfig.pipe_type_id:
		var pipe := PipeNode.new()
		pipe.name = node_name
		pipe.global_position = world_pos
		pipe.grid_position = grid_pos
		add_child(pipe)
		building_node = pipe
	elif building_type == GameConfig.water_source_type_id:
		var source := WaterSourceNode.new()
		source.name = node_name
		source.global_position = world_pos
		source.grid_position = grid_pos
		add_child(source)
		building_node = source
	else:
		var idx := 0
		if building_type.begins_with("type_"):
			idx = building_type.substr(5).to_int()
		var placeholder := Node2D.new()
		placeholder.name = node_name
		placeholder.global_position = world_pos
		placeholder.set_meta("building_type", building_type)
		building_node = placeholder
		var half_size := GameConfig.building_size / 2.0
		var box := ColorRect.new()
		box.size = Vector2(GameConfig.building_size, GameConfig.building_size)
		box.position = Vector2(-half_size, -half_size)
		var bg_color := _get_building_color(building_type)
		bg_color.a = 0.3
		box.color = bg_color
		placeholder.add_child(box)
		var label := Label.new()
		label.text = "占位-%d" % idx if idx > 0 else "占位"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(GameConfig.building_size, GameConfig.building_size)
		label.position = Vector2(-half_size, -half_size)
		var ls := LabelSettings.new()
		ls.font_size = 12
		ls.font_color = Color.WHITE
		label.label_settings = ls
		placeholder.add_child(label)
		add_child(placeholder)

	if BuildingData.is_container_building(building_node) and not restore_data.is_empty():
		if restore_data.has("capacity"):
			data.capacity = restore_data["capacity"]
			building_node.capacity = restore_data["capacity"]
		if restore_data.has("max_capacity"):
			data.max_capacity = restore_data["max_capacity"]
			building_node.max_capacity = restore_data["max_capacity"]

	_building_nodes[grid_pos] = building_node
	if building_node is PipeNode:
		fluid_pipes.append(building_node)
	elif building_node is WaterSourceNode:
		fluid_sources.append(building_node)
	buildings[grid_pos] = data
	EventBus.building_placed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
	return true

func remove_building(grid_pos: Vector2i) -> bool:
	if not has_building(grid_pos):
		return false

	var node := get_building_node(grid_pos)
	if node == null:
		return false
	if BuildingData.is_container_building(node):
		var data: BuildingData = buildings[grid_pos]
		data.capacity = node.capacity
		data.max_capacity = node.max_capacity
	node.queue_free()

	var node_to_remove = _building_nodes.get(grid_pos)
	if node_to_remove is PipeNode:
		fluid_pipes.erase(node_to_remove)
	elif node_to_remove is WaterSourceNode:
		fluid_sources.erase(node_to_remove)
	_building_nodes.erase(grid_pos)
	buildings.erase(grid_pos)
	EventBus.building_removed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
	return true

func get_all_buildings_data() -> Dictionary:
	var copy: Dictionary = {}
	for grid_pos in buildings.keys():
		var data: BuildingData = buildings[grid_pos]
		var new_data := BuildingData.new()
		new_data.grid_position = data.grid_position
		new_data.building_type = data.building_type
		new_data.capacity = data.capacity
		new_data.max_capacity = data.max_capacity
		copy[grid_pos] = new_data
	return copy

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

func set_paste_preview_line(anchors: Array[Vector2i], clipboard: Dictionary) -> void:
	paste_ghost_cells.clear()
	paste_ghost_types.clear()
	if clipboard.is_empty() or not clipboard.has("buildings"):
		queue_redraw()
		return
	var clip_buildings: Array[Dictionary] = clipboard["buildings"]
	var seen: Dictionary[Vector2i, bool] = {}
	for anchor in anchors:
		for item in clip_buildings:
			var grid_pos: Vector2i = anchor + item["offset"]
			if not seen.has(grid_pos):
				seen[grid_pos] = true
				paste_ghost_cells.append(grid_pos)
				paste_ghost_types[grid_pos] = item["type"]
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

func _draw_cell_highlight(cells: Array[Vector2i], fill_color: Color, border_color: Color, use_building_size: bool = false, border_width: float = 2.0) -> void:
	var cell_size := GameConfig.building_size if use_building_size else GameConfig.cell_size
	var half_size := cell_size / 2.0
	for grid_pos in cells:
		var world_pos := GridCoordinate.grid_to_world(grid_pos)
		var rect := Rect2(world_pos - Vector2(half_size, half_size), Vector2(cell_size, cell_size))
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, border_width)

func _draw() -> void:
	if not ghost_cells.is_empty():
		var ghost_fill := Color(1, 1, 1, GameConfig.ghost_alpha)
		var filtered_cells: Array[Vector2i] = []
		for grid_pos in ghost_cells:
			if not has_building(grid_pos):
				filtered_cells.append(grid_pos)
		_draw_cell_highlight(filtered_cells, ghost_fill, Color.WHITE, true, 2.0)

	if not remove_ghost_cells.is_empty():
		_draw_cell_highlight(remove_ghost_cells, Color(1, 0, 0, GameConfig.remove_ghost_alpha), Color.RED, false, 2.0)

	if not select_ghost_cells.is_empty():
		_draw_cell_highlight(select_ghost_cells, GameConfig.selection_highlight_color, GameConfig.selection_border_color, false, 2.0)

	if not deselect_ghost_cells.is_empty():
		_draw_cell_highlight(deselect_ghost_cells, Color(0.6, 0.2, 0.2, 0.3), Color(0.6, 0.2, 0.2, 0.8), false, 2.0)

	if not selected_cells.is_empty():
		_draw_cell_highlight(selected_cells, GameConfig.selection_highlight_color, GameConfig.selection_border_color, false, 2.0)

	if not paste_ghost_cells.is_empty():
		var alpha := GameConfig.paste_ghost_alpha
		for grid_pos in paste_ghost_cells:
			var building_type: String = paste_ghost_types.get(grid_pos, "default")
			var color := _get_building_color(building_type)
			color.a = alpha
			var border_color := color
			border_color.a = minf(alpha + 0.35, 1.0)
			_draw_cell_highlight([grid_pos], color, border_color, true, 2.0)

static func get_building_node_name(grid_pos: Vector2i) -> String:
	return "Building_%d_%d" % [grid_pos.x, grid_pos.y]

func get_building_type(grid_pos: Vector2i) -> String:
	if buildings.has(grid_pos):
		return buildings[grid_pos].building_type
	return ""

func get_building_data(grid_pos: Vector2i) -> BuildingData:
	return buildings.get(grid_pos) as BuildingData

func get_building_node(grid_pos: Vector2i) -> Node:
	return _building_nodes.get(grid_pos) as Node

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
	for offset in GridCoordinate.DIR_4:
		var npos: Vector2i = grid_pos + offset
		if has_building(npos):
			var node := get_building_node(npos)
			if node is PipeNode:
				node.refresh_connections()

	var self_node := get_building_node(grid_pos)
	if self_node is PipeNode:
		self_node.refresh_connections()
