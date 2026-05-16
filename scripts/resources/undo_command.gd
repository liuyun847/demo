class_name UndoCommand
extends RefCounted

enum Type { PLACE, REMOVE, PASTE, CUT }

var type: Type
var buildings: Dictionary = {}

func reverse(building_manager: BuildingManager) -> void:
	for grid_pos: Vector2i in buildings.keys():
		var entry: Dictionary = buildings[grid_pos]
		var building_type: String = entry.get("type", "default")
		match type:
			Type.PLACE, Type.PASTE:
				building_manager.remove_building(grid_pos)
			Type.REMOVE, Type.CUT:
				building_manager.place_building(grid_pos, building_type)

func forward(building_manager: BuildingManager) -> void:
	for grid_pos: Vector2i in buildings.keys():
		var entry: Dictionary = buildings[grid_pos]
		var building_type: String = entry.get("type", "default")
		match type:
			Type.PLACE, Type.PASTE:
				building_manager.place_building(grid_pos, building_type)
			Type.REMOVE, Type.CUT:
				building_manager.remove_building(grid_pos)
