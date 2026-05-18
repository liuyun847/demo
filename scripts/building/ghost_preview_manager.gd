class_name GhostPreviewManager
extends Node2D

var ghost_cells: Array[Vector2i] = []
var remove_ghost_cells: Array[Vector2i] = []
var selected_cells: Array[Vector2i] = []
var paste_ghost_cells: Array[Vector2i] = []
var paste_ghost_types: Dictionary[Vector2i, String] = {}
var select_ghost_cells: Array[Vector2i] = []
var deselect_ghost_cells: Array[Vector2i] = []


func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(cells: Array[Vector2i]) -> void:
	selected_cells = cells
	queue_redraw()


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


func _draw_cell_highlight(cells: Array[Vector2i], fill_color: Color, border_color: Color, use_building_size: bool = false, border_width: float = 2.0) -> void:
	var cell_size := GameConfig.building_size if use_building_size else GameConfig.cell_size
	var half_size := cell_size / 2.0
	for grid_pos in cells:
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


func _draw() -> void:
	if not ghost_cells.is_empty():
		var ghost_fill := Color(1, 1, 1, GameConfig.ghost_alpha)
		var bm := _get_building_manager()
		var filtered_cells: Array[Vector2i] = []
		for grid_pos in ghost_cells:
			if bm == null or not bm.has_building(grid_pos):
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


func _get_building_manager() -> BuildingManager:
	var parent := get_parent()
	if parent is BuildingManager:
		return parent
	return null
