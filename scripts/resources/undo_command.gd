class_name UndoCommand
extends RefCounted

enum Type { PLACE, REMOVE, PASTE, CUT }

const UNSET_MAX_CAPACITY := -1

var type: Type
var buildings: Dictionary = {}

func reverse(building_manager: BuildingManager) -> void:
	for grid_pos: Vector2i in buildings.keys():
		var entry = buildings[grid_pos]
		var building_type: String
		var restore_data: Dictionary = {}
		if entry is Dictionary:
			building_type = entry.get("type", "default")
			if entry.has("capacity"):
				restore_data["capacity"] = entry["capacity"]
			if entry.has("max_capacity"):
				restore_data["max_capacity"] = entry["max_capacity"]
		else:
			building_type = entry as String
		match type:
			Type.PLACE, Type.PASTE:
				building_manager.remove_building(grid_pos)
			Type.REMOVE, Type.CUT:
				building_manager.place_building(grid_pos, building_type, restore_data)
