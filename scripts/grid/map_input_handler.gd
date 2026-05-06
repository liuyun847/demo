extends Node

@onready var building_manager: BuildingManager = get_node("../BuildingManager")
@onready var inventory_bar: InventoryBar = get_node("../UIOverlay/InventoryBar")

enum InteractionMode {NONE, PLACE, REMOVE, SELECT, DESELECT, PASTE}
var _current_mode: InteractionMode = InteractionMode.NONE

var _drag_start_grid: Vector2i
var _removing_start_grid: Vector2i
var _select_start_grid: Vector2i
var _deselect_start_grid: Vector2i

var _is_dragging: bool = false
var _is_removing: bool = false
var _is_selecting: bool = false
var _is_deselecting: bool = false

func _ready() -> void:
	if inventory_bar:
		inventory_bar.slot_selected.connect(_on_slot_selected)
	EventBus.paste_mode_changed.connect(_on_paste_mode_changed)

func _on_slot_selected(index: int, _type_id: String) -> void:
	if index < 0:
		_cancel_all_dragging()

func _on_paste_mode_changed(active: bool) -> void:
	_cancel_all_dragging()

func _cancel_all_dragging() -> void:
	building_manager.clear_paste_preview()
	if _is_dragging:
		building_manager.hide_ghost()
		_is_dragging = false
	if _is_removing:
		building_manager.hide_remove_ghost()
		_is_removing = false
	if _is_selecting:
		building_manager.hide_select_ghost()
		_is_selecting = false
	if _is_deselecting:
		building_manager.hide_deselect_ghost()
		_is_deselecting = false

func _get_grid_pos(event: InputEvent) -> Vector2i:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if not camera:
		return Vector2i.ZERO
	var world_pos: Vector2 = GridCoordinate.screen_to_world(camera, event.position)
	return GridCoordinate.world_to_grid(world_pos)

func _is_building_placement_mode() -> bool:
	return inventory_bar and inventory_bar.has_building_type_selected() and not SelectionManager.is_paste_mode

func _is_paste_mode() -> bool:
	return SelectionManager.is_paste_mode

func _is_selection_mode() -> bool:
	return not _is_building_placement_mode() and not _is_paste_mode()

func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if not viewport.get_camera_2d():
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event, viewport)
		return

	if not event is InputEventMouseButton:
		return

	var grid_pos := _get_grid_pos(event)

	if _is_paste_mode():
		_handle_paste_mode(event, grid_pos, viewport)
		return

	if _is_building_placement_mode():
		_handle_building_mode(event, grid_pos, viewport)
		return

	if _is_selection_mode():
		_handle_selection_mode(event, grid_pos, viewport)

func _handle_mouse_motion(event: InputEventMouseMotion, viewport: Viewport) -> void:
	if _is_paste_mode():
		var grid_pos := _get_grid_pos(event)
		SelectionManager.paste_anchor = grid_pos
		building_manager.set_paste_preview(grid_pos, SelectionManager.clipboard)
		viewport.set_input_as_handled()
		return

	if _is_building_placement_mode():
		if _is_dragging:
			var grid_pos := _get_grid_pos(event)
			if grid_pos != _drag_start_grid:
				var cells := BuildingManager.get_line_cells(_drag_start_grid, grid_pos)
				building_manager.show_ghost(cells)
			viewport.set_input_as_handled()
			return
		if _is_removing:
			var grid_pos := _get_grid_pos(event)
			if grid_pos != _removing_start_grid:
				var cells := BuildingManager.get_rect_cells(_removing_start_grid, grid_pos)
				building_manager.show_remove_ghost(cells)
			viewport.set_input_as_handled()
			return

	if _is_selection_mode():
		if _is_selecting:
			var grid_pos := _get_grid_pos(event)
			if grid_pos != _select_start_grid:
				var cells := BuildingManager.get_rect_cells(_select_start_grid, grid_pos)
				building_manager.show_select_ghost(cells)
			viewport.set_input_as_handled()
			return
		if _is_deselecting:
			var grid_pos := _get_grid_pos(event)
			if grid_pos != _deselect_start_grid:
				var cells := BuildingManager.get_rect_cells(_deselect_start_grid, grid_pos)
				building_manager.show_deselect_ghost(cells)
			viewport.set_input_as_handled()
			return

func _handle_paste_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.perform_paste(grid_pos)
		viewport.set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		SelectionManager.cancel_paste_mode()
		building_manager.clear_paste_preview()
		viewport.set_input_as_handled()
		return

func _handle_building_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.is_action("place_building") and event.pressed:
		if _is_removing:
			building_manager.hide_remove_ghost()
			_is_removing = false
		if _is_selecting:
			building_manager.hide_select_ghost()
			_is_selecting = false
		if _is_deselecting:
			building_manager.hide_deselect_ghost()
			_is_deselecting = false
		_is_dragging = true
		_drag_start_grid = grid_pos
		building_manager.show_ghost([grid_pos])
		viewport.set_input_as_handled()
		return

	if event.is_action("place_building") and not event.pressed and _is_dragging:
		var cells := BuildingManager.get_line_cells(_drag_start_grid, grid_pos)
		var building_type := inventory_bar.get_current_building_type() if inventory_bar else "default"
		var placed := {}
		for cell in cells:
			if building_manager.place_building(cell, building_type):
				placed[cell] = building_type
		if not placed.is_empty():
			var cmd := UndoCommand.new()
			cmd.type = UndoCommand.Type.PLACE
			cmd.buildings = placed
			SelectionManager.push_undo_command(cmd)
		building_manager.hide_ghost()
		_is_dragging = false
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and event.pressed:
		if _is_dragging:
			building_manager.hide_ghost()
			_is_dragging = false
			viewport.set_input_as_handled()
			return
		if _is_selecting:
			building_manager.hide_select_ghost()
			_is_selecting = false
		if _is_deselecting:
			building_manager.hide_deselect_ghost()
			_is_deselecting = false
		if _is_removing:
			building_manager.hide_remove_ghost()
			_is_removing = false
		_is_removing = true
		_removing_start_grid = grid_pos
		building_manager.show_remove_ghost([grid_pos])
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and not event.pressed and _is_removing:
		var cells := BuildingManager.get_rect_cells(_removing_start_grid, grid_pos)
		var removed := {}
		for cell in cells:
			if building_manager.has_building(cell):
				var entry := {"type": building_manager.buildings[cell].building_type}
				var node := building_manager.get_node_or_null("Building_%d_%d" % [cell.x, cell.y])
				if node is ContainerNode or node is PipeNode:
					entry["capacity"] = node.capacity
					entry["max_capacity"] = node.max_capacity
				removed[cell] = entry
		building_manager.remove_buildings_in_rect(cells)
		if not removed.is_empty():
			var cmd := UndoCommand.new()
			cmd.type = UndoCommand.Type.REMOVE
			cmd.buildings = removed
			SelectionManager.push_undo_command(cmd)
		building_manager.hide_remove_ghost()
		_is_removing = false
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and not event.pressed:
		viewport.set_input_as_handled()
		return

func _handle_selection_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_removing:
			building_manager.hide_remove_ghost()
			_is_removing = false
		if _is_deselecting:
			building_manager.hide_deselect_ghost()
			_is_deselecting = false
		_is_selecting = true
		_select_start_grid = grid_pos
		building_manager.show_select_ghost([grid_pos])
		viewport.set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _is_selecting:
		var cells := BuildingManager.get_rect_cells(_select_start_grid, grid_pos)
		SelectionManager.select_rect(cells)
		building_manager.hide_select_ghost()
		_is_selecting = false
		viewport.set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _is_selecting:
			building_manager.hide_select_ghost()
			_is_selecting = false
		_is_deselecting = true
		_deselect_start_grid = grid_pos
		building_manager.show_deselect_ghost([grid_pos])
		viewport.set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and _is_deselecting:
		var cells := BuildingManager.get_rect_cells(_deselect_start_grid, grid_pos)
		SelectionManager.deselect_rect(cells)
		building_manager.hide_deselect_ghost()
		_is_deselecting = false
		viewport.set_input_as_handled()
		return
