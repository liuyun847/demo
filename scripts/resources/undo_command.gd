class_name UndoCommand
extends RefCounted

enum Type { PLACE, REMOVE, PASTE, CUT }

var type: Type
var buildings: Dictionary = {}

func reverse(building_manager: BuildingManager) -> void:
	for grid_pos: Vector2i in buildings.keys():
		var entry = buildings[grid_pos]
		var building_type: String
		var capacity: int = 0
		var max_capacity: int = -1
		if entry is Dictionary:
			building_type = entry.get("type", "default")
			capacity = entry.get("capacity", 0)
			max_capacity = entry.get("max_capacity", -1)
		else:
			building_type = entry as String
		match type:
			Type.PLACE, Type.PASTE:
				building_manager.remove_building(grid_pos)
			Type.REMOVE, Type.CUT:
				building_manager.place_building(grid_pos, building_type, capacity, max_capacity)
