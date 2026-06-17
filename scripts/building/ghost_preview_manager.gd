class_name GhostPreviewManager
extends Node2D

var _ghost_layers: Dictionary = {}
var paste_ghost_types: Dictionary[Vector2i, String] = {}
var emitter_ghost_direction: Vector2i = Vector2i.ZERO
var _collector_ghost_active: bool = false


func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(cells: Array[Vector2i]) -> void:
	_ghost_layers["selected"] = cells
	queue_redraw()


func set_selected_cells(cells: Array[Vector2i]) -> void:
	_ghost_layers["selected"] = cells
	queue_redraw()


func show_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["ghost"] = cells
	queue_redraw()


func hide_ghost() -> void:
	_ghost_layers.erase("ghost")
	queue_redraw()


func show_remove_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["remove_ghost"] = cells
	queue_redraw()


func hide_remove_ghost() -> void:
	_ghost_layers.erase("remove_ghost")
	queue_redraw()


func show_select_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["select_ghost"] = cells
	queue_redraw()


func hide_select_ghost() -> void:
	_ghost_layers.erase("select_ghost")
	queue_redraw()


func show_deselect_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["deselect_ghost"] = cells
	queue_redraw()


func hide_deselect_ghost() -> void:
	_ghost_layers.erase("deselect_ghost")
	queue_redraw()


func set_paste_preview_line(anchors: Array[Vector2i], clipboard: Dictionary) -> void:
	_ghost_layers.erase("paste_ghost")
	paste_ghost_types.clear()
	if clipboard.is_empty() or not clipboard.has("buildings"):
		queue_redraw()
		return
	var clip_buildings: Array = clipboard["buildings"]
	var paste_ghost_cells: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for anchor: Vector2i in anchors:
		for item: Dictionary in clip_buildings:
			var grid_pos: Vector2i = anchor + item["offset"]
			if not seen.has(grid_pos):
				seen[grid_pos] = true
				paste_ghost_cells.append(grid_pos)
				paste_ghost_types[grid_pos] = item["type"]
	_ghost_layers["paste_ghost"] = paste_ghost_cells
	queue_redraw()


func clear_paste_preview() -> void:
	_ghost_layers.erase("paste_ghost")
	paste_ghost_types.clear()
	queue_redraw()


func set_emitter_ghost_direction(dir: Vector2i) -> void:
	emitter_ghost_direction = dir
	queue_redraw()


func hide_emitter_ghost_direction() -> void:
	emitter_ghost_direction = Vector2i.ZERO
	queue_redraw()


func show_collector_ghost_range() -> void:
	_collector_ghost_active = true
	queue_redraw()


func hide_collector_ghost_range() -> void:
	_collector_ghost_active = false
	queue_redraw()


func get_layer_cells(layer_name: String) -> Array:
	return _ghost_layers.get(layer_name, [])


func _draw() -> void:
	var bm := _get_building_manager()

	var ghost_cells: Array = _ghost_layers.get("ghost", [])
	if not ghost_cells.is_empty():
		var ghost_fill := Color(1, 1, 1, GameConfig.ghost_alpha)
		var filtered_cells: Array[Vector2i] = []
		for grid_pos: Vector2i in ghost_cells:
			if bm == null or not bm.has_building(grid_pos):
				filtered_cells.append(grid_pos)
		_draw_cell_highlight(filtered_cells, ghost_fill, Color.WHITE, true, 2.0)

	var remove_ghost_cells: Array = _ghost_layers.get("remove_ghost", [])
	if not remove_ghost_cells.is_empty():
		_draw_cell_highlight(remove_ghost_cells, Color(1, 0, 0, GameConfig.remove_ghost_alpha), Color.RED, false, 2.0)

	var select_ghost_cells: Array = _ghost_layers.get("select_ghost", [])
	if not select_ghost_cells.is_empty():
		_draw_cell_highlight(select_ghost_cells, GameConfig.selection_highlight_color, GameConfig.selection_border_color, false, 2.0)

	var deselect_ghost_cells: Array = _ghost_layers.get("deselect_ghost", [])
	if not deselect_ghost_cells.is_empty():
		_draw_cell_highlight(deselect_ghost_cells, Color(0.6, 0.2, 0.2, 0.3), Color(0.6, 0.2, 0.2, 0.8), false, 2.0)

	var selected_cells: Array = _ghost_layers.get("selected", [])
	if not selected_cells.is_empty():
		_draw_cell_highlight(selected_cells, GameConfig.selection_highlight_color, GameConfig.selection_border_color, false, 2.0)

	var paste_ghost_cells: Array = _ghost_layers.get("paste_ghost", [])
	if not paste_ghost_cells.is_empty():
		for grid_pos: Vector2i in paste_ghost_cells:
			var building_type: String = paste_ghost_types.get(grid_pos, "default")
			var color := _get_building_color(building_type)
			color.a = GameConfig.paste_ghost_alpha
			var border_color := color
			border_color.a = mini(color.a + 0.35, 1.0)
			_draw_cell_highlight([grid_pos], color, border_color, true, 2.0)

	if emitter_ghost_direction != Vector2i.ZERO and not ghost_cells.is_empty():
		for grid_pos: Vector2i in ghost_cells:
			_draw_emitter_arrow_at(grid_pos, emitter_ghost_direction)

	if _collector_ghost_active and not ghost_cells.is_empty():
		var radius := GameConfig.collector_default_radius
		for grid_pos: Vector2i in ghost_cells:
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if dx == 0 and dy == 0:
						continue
					var arrow_pos := grid_pos + Vector2i(dx, dy)
					var arrow_dir := Vector2i(-dx, -dy)
					_draw_arrow_at(arrow_pos, arrow_dir)


func _draw_cell_highlight(cells: Array, fill_color: Color, border_color: Color, use_building_size: bool = false, border_width: float = 2.0) -> void:
	var cell_size: float = GameConfig.building_size if use_building_size else GameConfig.cell_size
	var half_size: float = cell_size / 2.0
	for grid_pos: Vector2i in cells:
		var world_pos := GridCoordinate.grid_to_world(grid_pos)
		var rect := Rect2(world_pos - Vector2(half_size, half_size), Vector2(cell_size, cell_size))
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, border_width)


func _get_building_color(building_type: String) -> Color:
	if building_type == "default":
		return GameConfig.building_default_color
	if building_type.begins_with("type_"):
		var idx := building_type.substr(5).to_int()
		if idx >= 1 and idx <= 10:
			return Color.from_hsv(float(idx - 1) / 10.0, 0.7, 0.9)
	return GameConfig.building_default_color


func _draw_arrow_at(cell_pos: Vector2i, direction: Vector2i) -> void:
	# 在指定格子中心画一个箭头，指向 direction 方向
	var half: float = GameConfig.building_size / 2.0
	var world_pos := GridCoordinate.grid_to_world(cell_pos)
	var dir_vec := Vector2(direction)
	var arrow_size: float = half * 0.65
	var center_offset := dir_vec * arrow_size * 0.2
	var tip_offset := dir_vec * arrow_size * 0.55
	var perp := Vector2(-dir_vec.y, dir_vec.x)
	var tip := world_pos + center_offset + tip_offset
	var left := world_pos + center_offset + perp * arrow_size * 0.3
	var right := world_pos + center_offset - perp * arrow_size * 0.3
	var vertices := PackedVector2Array([tip, left, right])
	draw_colored_polygon(vertices, Color(1, 1, 1, GameConfig.ghost_alpha))
	draw_polyline(vertices, Color.WHITE, 1.5)
	draw_line(vertices[2], vertices[0], Color.WHITE, 1.5)


func _draw_emitter_arrow_at(grid_pos: Vector2i, direction: Vector2i) -> void:
	_draw_arrow_at(grid_pos + direction, direction)


func _get_building_manager() -> BuildingManager:
	var parent := get_parent()
	if parent is BuildingManager:
		return parent
	return null
