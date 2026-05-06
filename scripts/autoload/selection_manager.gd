extends Node

var selected_cells: Dictionary = {}
var clipboard: Dictionary = {}
var undo_stack: Array[UndoCommand] = []
var is_paste_mode: bool = false
var paste_anchor: Vector2i = Vector2i.ZERO

const MAX_UNDO_SIZE: int = 100

var _building_manager: BuildingManager = null

func _get_building_manager() -> BuildingManager:
	if _building_manager == null:
		var main := get_node_or_null("/root/Root")
		if main:
			_building_manager = main.get_node_or_null("BuildingManager") as BuildingManager
	return _building_manager

func _get_selected_cells_array() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(selected_cells.keys())
	return result

func select_cell(grid_pos: Vector2i) -> void:
	selected_cells[grid_pos] = true
	EventBus.selection_changed.emit(_get_selected_cells_array())

func deselect_cell(grid_pos: Vector2i) -> void:
	selected_cells.erase(grid_pos)
	EventBus.selection_changed.emit(_get_selected_cells_array())

func clear_selection() -> void:
	selected_cells.clear()
	EventBus.selection_changed.emit(_get_selected_cells_array())

func select_rect(cells: Array[Vector2i]) -> void:
	var building_manager := _get_building_manager()
	if not building_manager:
		return
	var old_selection := selected_cells.duplicate()
	for grid_pos in cells:
		if building_manager.has_building(grid_pos):
			selected_cells[grid_pos] = true
	if selected_cells != old_selection:
		EventBus.selection_changed.emit(_get_selected_cells_array())

func deselect_rect(cells: Array[Vector2i]) -> void:
	var old_selection := selected_cells.duplicate()
	for grid_pos in cells:
		selected_cells.erase(grid_pos)
	if selected_cells != old_selection:
		EventBus.selection_changed.emit(_get_selected_cells_array())

func _build_clipboard(cut: bool) -> Dictionary:
	var building_manager := _get_building_manager()
	if not building_manager:
		return {}
	if selected_cells.is_empty():
		return {}

	var buildings_data := building_manager.get_buildings_in_cells(_get_selected_cells_array())
	if buildings_data.is_empty():
		return {}

	var grid_keys := buildings_data.keys()
	var min_x: int = grid_keys[0].x
	var min_y: int = grid_keys[0].y
	for grid_pos: Vector2i in grid_keys:
		min_x = mini(min_x, grid_pos.x)
		min_y = mini(min_y, grid_pos.y)

	var clipboard_buildings: Array[Dictionary] = []
	for grid_pos: Vector2i in grid_keys:
		var offset := Vector2i(grid_pos.x - min_x, grid_pos.y - min_y)
		clipboard_buildings.append({
			"offset": offset,
			"type": buildings_data[grid_pos]
		})

	var result := {
		"buildings": clipboard_buildings,
		"was_cut": cut
	}

	if cut:
		var cmd := UndoCommand.new()
		cmd.type = UndoCommand.Type.CUT
		var undo_buildings := {}
		for grid_pos: Vector2i in grid_keys:
			var type_id: String = buildings_data[grid_pos]
			var entry := {"type": type_id}
			var node := building_manager.get_node_or_null("Building_%d_%d" % [grid_pos.x, grid_pos.y])
			if node is ContainerNode or node is PipeNode:
				entry["capacity"] = node.capacity
				entry["max_capacity"] = node.max_capacity
			undo_buildings[grid_pos] = entry
		cmd.buildings = undo_buildings
		undo_stack.append(cmd)

		for grid_pos in buildings_data.keys():
			building_manager.remove_building(grid_pos)
			selected_cells.erase(grid_pos)

		EventBus.selection_changed.emit(_get_selected_cells_array())

	return result

func copy_selection() -> void:
	clipboard = _build_clipboard(false)

func cut_selection() -> void:
	clipboard = _build_clipboard(true)

func start_paste_mode() -> void:
	if clipboard.is_empty() or not clipboard.has("buildings"):
		return
	is_paste_mode = true
	paste_anchor = Vector2i.ZERO
	EventBus.paste_mode_changed.emit(true)

func cancel_paste_mode() -> void:
	is_paste_mode = false
	paste_anchor = Vector2i.ZERO
	EventBus.paste_mode_changed.emit(false)

func perform_paste(anchor: Vector2i) -> void:
	var building_manager := _get_building_manager()
	if not building_manager:
		return
	if clipboard.is_empty() or not clipboard.has("buildings"):
		return

	var paste_buildings: Array[Dictionary] = clipboard["buildings"]

	var placed_cells := {}
	for item in paste_buildings:
		var grid_pos: Vector2i = anchor + item["offset"]
		var building_type: String = item["type"]
		if building_manager.place_building(grid_pos, building_type):
			placed_cells[grid_pos] = building_type

	if not placed_cells.is_empty():
		var cmd := UndoCommand.new()
		cmd.type = UndoCommand.Type.PASTE
		cmd.buildings = placed_cells
		undo_stack.append(cmd)

	is_paste_mode = false
	EventBus.paste_mode_changed.emit(false)
	selected_cells.clear()
	EventBus.selection_changed.emit(_get_selected_cells_array())

func undo() -> void:
	if undo_stack.is_empty():
		return
	var cmd: UndoCommand = undo_stack.pop_back()
	var building_manager := _get_building_manager()
	if building_manager:
		cmd.reverse(building_manager)

func push_undo_command(cmd: UndoCommand) -> void:
	undo_stack.append(cmd)
	if undo_stack.size() > MAX_UNDO_SIZE:
		undo_stack.remove_at(0)
