extends Node

@onready var building_manager: BuildingManager = get_node("../BuildingManager")
@onready var grid_coordinate: GridCoordinate = get_node("../GridCoordinate")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if not camera:
		return

	var world_pos: Vector2 = grid_coordinate.screen_to_world(camera, event.position)
	var grid_pos: Vector2i = grid_coordinate.world_to_grid(world_pos)

	if event.is_action("place_building"):
		building_manager.place_building(grid_pos)
		viewport.set_input_as_handled()
	elif event.is_action("remove_building"):
		building_manager.remove_building(grid_pos)
		viewport.set_input_as_handled()
