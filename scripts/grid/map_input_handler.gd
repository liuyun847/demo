extends Node

@onready var building_manager: BuildingManager = get_node("../BuildingManager")

var _is_dragging: bool = false
var _drag_start_grid: Vector2i

var _is_removing: bool = false
var _removing_start_grid: Vector2i

func _get_grid_pos(event: InputEvent) -> Vector2i:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if not camera:
		return Vector2i.ZERO
	var world_pos: Vector2 = GridCoordinate.screen_to_world(camera, event.position)
	return GridCoordinate.world_to_grid(world_pos)

func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if not viewport.get_camera_2d():
		return

	if event is InputEventMouseMotion:
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

	if not event is InputEventMouseButton:
		return

	var grid_pos := _get_grid_pos(event)

	if event.is_action("place_building") and event.pressed:
		if _is_removing:
			building_manager.hide_remove_ghost()
			_is_removing = false
		_is_dragging = true
		_drag_start_grid = grid_pos
		building_manager.show_ghost([grid_pos])
		viewport.set_input_as_handled()
		return

	if event.is_action("place_building") and not event.pressed and _is_dragging:
		var cells := BuildingManager.get_line_cells(_drag_start_grid, grid_pos)
		building_manager.place_buildings_in_line(cells)
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
		building_manager.remove_buildings_in_rect(cells)
		building_manager.hide_remove_ghost()
		_is_removing = false
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and not event.pressed:
		viewport.set_input_as_handled()
		return
