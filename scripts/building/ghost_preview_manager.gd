class_name GhostPreviewManager
extends Node2D

var _ghost_layers: Dictionary = {}
var paste_ghost_types: Dictionary[Vector2i, String] = {}
var _collector_ghost_active: bool = false


func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)


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
		var ghost_fill := Color(1, 1, 1, GameConfig.GHOST_ALPHA)
		var filtered_cells: Array[Vector2i] = []
		for grid_pos: Vector2i in ghost_cells:
			if bm == null or not bm.has_building(grid_pos):
				filtered_cells.append(grid_pos)
		_draw_cell_highlight(filtered_cells, ghost_fill, Color.WHITE, true, 2.0)

	var remove_ghost_cells: Array = _ghost_layers.get("remove_ghost", [])
	if not remove_ghost_cells.is_empty():
		_draw_cell_highlight(remove_ghost_cells, Color(1, 0, 0, GameConfig.REMOVE_GHOST_ALPHA), Color.RED, false, 2.0)

	var select_ghost_cells: Array = _ghost_layers.get("select_ghost", [])
	if not select_ghost_cells.is_empty():
		_draw_cell_highlight(select_ghost_cells, GameConfig.SELECTION_HIGHLIGHT_COLOR, GameConfig.SELECTION_BORDER_COLOR, false, 2.0)

	var deselect_ghost_cells: Array = _ghost_layers.get("deselect_ghost", [])
	if not deselect_ghost_cells.is_empty():
		_draw_cell_highlight(deselect_ghost_cells, Color(0.6, 0.2, 0.2, 0.3), Color(0.6, 0.2, 0.2, 0.8), false, 2.0)

	var selected_cells: Array = _ghost_layers.get("selected", [])
	if not selected_cells.is_empty():
		_draw_cell_highlight(selected_cells, GameConfig.SELECTION_HIGHLIGHT_COLOR, GameConfig.SELECTION_BORDER_COLOR, false, 2.0)

	var paste_ghost_cells: Array = _ghost_layers.get("paste_ghost", [])
	if not paste_ghost_cells.is_empty():
		for grid_pos: Vector2i in paste_ghost_cells:
			var building_type: String = paste_ghost_types.get(grid_pos, "default")
			var color := BuildingTypeManager.get_building_color(building_type)
			color.a = GameConfig.PASTE_GHOST_ALPHA
			var border_color := color
			border_color.a = mini(color.a + 0.35, 1.0)
			_draw_cell_highlight([grid_pos], color, border_color, true, 2.0)

	if _collector_ghost_active and not ghost_cells.is_empty():
		# 仅对代表格画一个范围框，而非每个 ghost cell 都画 (2r+1)² 个箭头
		var center: Vector2i = ghost_cells[0]
		_draw_collector_range_rect(center, GameConfig.COLLECTOR_DEFAULT_RADIUS)


func _draw_cell_highlight(cells: Array, fill_color: Color, border_color: Color, use_building_size: bool = false, border_width: float = 2.0) -> void:
	var cell_size: float = GameConfig.BUILDING_SIZE if use_building_size else GameConfig.CELL_SIZE
	var half_size: float = cell_size / 2.0
	for grid_pos: Vector2i in cells:
		var world_pos := GridCoordinate.grid_to_world(grid_pos)
		var rect := Rect2(world_pos - Vector2(half_size, half_size), Vector2(cell_size, cell_size))
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, border_width)


## 画收集器范围指示框：在中心格周围画半径为 radius 的矩形填充+边框
func _draw_collector_range_rect(center: Vector2i, radius: int) -> void:
	var center_world := GridCoordinate.grid_to_world(center)
	# 范围框：以 center 为中心，边长 = (2*radius + 1) 个 cell
	var cell_size := float(GameConfig.CELL_SIZE)
	var half_size := cell_size * (radius + 0.5)
	var rect := Rect2(center_world - Vector2(half_size, half_size), Vector2(half_size * 2.0, half_size * 2.0))
	var fill_color := Color(0.2, 0.6, 1.0, 0.15)
	var border_color := Color(0.2, 0.6, 1.0, 0.6)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, 2.0)


func _get_building_manager() -> BuildingManager:
	var parent := get_parent()
	if parent is BuildingManager:
		return parent
	return null
