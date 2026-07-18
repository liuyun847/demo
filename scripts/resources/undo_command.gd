class_name UndoCommand
extends RefCounted

## 撤销/重做命令。封装对建筑系统的正向/逆向操作，支持 PLACE/REMOVE/PASTE/CUT 四种类型。
## 注意源质经济策略（保持现状，非闭环设计）：
## - reverse(PLACE) 调用 remove_building 但不退还源质（防止玩家通过撤销反复刷源质）
## - forward(PLACE)（重做）跳过扣费（因 restore_data 非空，视为"恢复"而非"新建"）
## 这是有意的防刷设计，撤销被视为"放弃操作"而非"倒带"，源质流动单向不可逆。
enum Type { PLACE, REMOVE, PASTE, CUT }

var type: Type
var buildings: Dictionary = {}

func reverse(building_manager: BuildingManager) -> void:
	## 逆向执行：PLACE/PASTE 变为移除，REMOVE/CUT 变为恢复。
	## 注意：移除建筑时不退还源质（防刷策略，见类文档说明）。
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
				if entry.has("collector_filter"):
					restore_data["collector_filter"] = entry["collector_filter"]
				building_manager.place_building(grid_pos, building_type, restore_data)

func forward(building_manager: BuildingManager) -> void:
	## 正向重做：PLACE/PASTE 重新放置但不扣费（视为恢复已撤销的操作），REMOVE/CUT 重新移除。
	## 注意：重做不扣源质（防刷策略，见类文档说明）。
	for grid_pos: Vector2i in buildings.keys():
		var entry: Dictionary = buildings[grid_pos]
		var building_type: String = entry.get("type", "default")
		match type:
			Type.PLACE, Type.PASTE:
				var restore_data: Dictionary = {}
				if entry.has("element_type_id"):
					restore_data["element_type_id"] = entry["element_type_id"]
				if entry.has("collector_filter"):
					restore_data["collector_filter"] = entry["collector_filter"]
				building_manager.place_building(grid_pos, building_type, restore_data)
			Type.REMOVE, Type.CUT:
				building_manager.remove_building(grid_pos)
