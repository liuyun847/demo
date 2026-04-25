extends Node

@onready var building_manager: BuildingManager = get_node("../BuildingManager")

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)
	load_buildings()

func _on_building_changed(_grid_pos: Vector2i) -> void:
	save_buildings()

func save_buildings() -> void:
	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	var buildings_data: Dictionary = building_manager.get_all_buildings_data()
	var save_dict := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"buildings": {}
	}

	for grid_pos in buildings_data.keys():
		var data: BuildingData = buildings_data[grid_pos]
		var key := "%d,%d" % [grid_pos.x, grid_pos.y]
		save_dict.buildings[key] = {
			"type": data.building_type
		}

	var dir_path := GameConfig.save_file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(GameConfig.save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()
	else:
		push_error("SaveManager: 无法写入存档文件: %s" % GameConfig.save_file_path)

func load_buildings() -> void:
	if not FileAccess.file_exists(GameConfig.save_file_path):
		return

	var file := FileAccess.open(GameConfig.save_file_path, FileAccess.READ)
	if not file:
		push_error("SaveManager: 无法读取存档文件: %s" % GameConfig.save_file_path)
		return

	var content := file.get_as_text()
	file.close()

	var save_data = JSON.parse_string(content)
	if save_data == null or not save_data is Dictionary:
		push_error("SaveManager: 存档格式无效")
		return

	if not save_data.has("version"):
		push_error("SaveManager: 存档缺少版本号")
		return

	if save_data.version != GameConfig.SAVE_VERSION:
		push_warning("SaveManager: 存档版本不匹配，期望 %s，实际 %s" % [GameConfig.SAVE_VERSION, save_data.version])

	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	building_manager.clear_all_buildings()

	if save_data.has("buildings") and save_data.buildings is Dictionary:
		for key in save_data.buildings.keys():
			var parts: PackedStringArray = key.split(",")
			if parts.size() == 2:
				var grid_pos := Vector2i(int(parts[0]), int(parts[1]))
				var b_data: Dictionary = save_data.buildings[key]
				var b_type: String = b_data.get("type", "default")
				building_manager.place_building(grid_pos, b_type)

	EventBus.buildings_loaded.emit()
