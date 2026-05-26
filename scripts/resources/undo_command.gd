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
				var restore_data: Dictionary = {}
				if entry.has("element_type_id"):
					restore_data["element_type_id"] = entry["element_type_id"]
				building_manager.place_building(grid_pos, building_type, restore_data)

func forward(building_manager: BuildingManager) -> void:
	for grid_pos: Vector2i in buildings.keys():
		var entry: Dictionary = buildings[grid_pos]
		var building_type: String = entry.get("type", "default")
		match type:
			Type.PLACE, Type.PASTE:
				var restore_data: Dictionary = {}
				if entry.has("element_type_id"):
					restore_data["element_type_id"] = entry["element_type_id"]
				building_manager.place_building(grid_pos, building_type, restore_data)
			Type.REMOVE, Type.CUT:
				building_manager.remove_building(grid_pos)
