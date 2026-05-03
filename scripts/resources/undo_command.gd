class_name UndoCommand
extends RefCounted

enum Type { PLACE, REMOVE, PASTE, CUT }

var type: Type
var buildings: Dictionary = {}

func reverse(building_manager: BuildingManager) -> void:
	for grid_pos: Vector2i in buildings.keys():
		var building_type: String = buildings[grid_pos]
		match type:
			Type.PLACE, Type.PASTE:
				building_manager.remove_building(grid_pos)
			Type.REMOVE, Type.CUT:
				building_manager.place_building(grid_pos, building_type)
