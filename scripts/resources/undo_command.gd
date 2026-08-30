class_name UndoCommand
extends RefCounted

## 撤销/重做命令。封装对建筑系统的正向/逆向操作，支持 PLACE/REMOVE/PASTE/CUT 四种类型。
## 源质经济策略见旧版注释（纯搭建阶段费用为 0，防刷逻辑保留但不生效）。
## 物品流建筑状态（direction/op_choice/splitter_phase/splitter_in_phase/splitter_filters）经
## BuildingDataSyncService 的 entry <-> restore_data 助手完整保存/恢复。
enum Type { PLACE, REMOVE, PASTE, CUT }

var type: Type
var buildings: Dictionary = {}
## 放置前该格已有建筑的条目（如"放分流器到传送带上"转换前的原传送带）。
## reverse 还原 PLACE/PASTE 时优先恢复前者，避免一体建筑删除时把原带一并丢掉。
var previous: Dictionary = {}

func reverse(building_manager: BuildingManager) -> void:
	## 逆向执行：PLACE/PASTE 变为移除（曾占用格的恢复原建筑），REMOVE/CUT 变为恢复。
	for grid_pos: Vector2i in buildings.keys():
		var entry: Dictionary = buildings[grid_pos]
		var building_type: String = entry.get("type", "default")
		match type:
			Type.PLACE, Type.PASTE:
				if previous.has(grid_pos):
					# 曾占用格（如分流器放传送带转换）：先移除一体建筑，再还原原建筑
					building_manager.remove_building(grid_pos)
					var prev_entry: Dictionary = previous[grid_pos]
					var prev_type: String = prev_entry.get("type", "default")
					var prev_restore: Dictionary = BuildingDataSyncService.entry_to_restore_data(prev_entry)
					building_manager.place_building(grid_pos, prev_type, prev_restore)
				else:
					building_manager.remove_building(grid_pos)
			Type.REMOVE, Type.CUT:
				var restore_data: Dictionary = BuildingDataSyncService.entry_to_restore_data(entry)
				building_manager.place_building(grid_pos, building_type, restore_data)

func forward(building_manager: BuildingManager) -> void:
	## 正向重做：PLACE/PASTE 重新放置（restore_data 非空视为恢复，不扣费），REMOVE/CUT 重新移除。
	for grid_pos: Vector2i in buildings.keys():
		var entry: Dictionary = buildings[grid_pos]
		var building_type: String = entry.get("type", "default")
		match type:
			Type.PLACE, Type.PASTE:
				var restore_data: Dictionary = BuildingDataSyncService.entry_to_restore_data(entry)
				building_manager.place_building(grid_pos, building_type, restore_data)
			Type.REMOVE, Type.CUT:
				building_manager.remove_building(grid_pos)