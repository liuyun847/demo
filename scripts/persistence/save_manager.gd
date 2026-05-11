extends Node

@onready var building_manager: BuildingManager = get_node("../BuildingManager")

var _is_loading: bool = false
var _save_pending: bool = false

var _fluid_autosave_timer: Timer = null
const FLUID_AUTOSAVE_DELAY: float = 3.0

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)
	EventBus.fluid_updated.connect(_on_fluid_updated)
	_init_fluid_autosave_timer()
	load_buildings()

func _init_fluid_autosave_timer() -> void:
	_fluid_autosave_timer = Timer.new()
	_fluid_autosave_timer.one_shot = true
	_fluid_autosave_timer.timeout.connect(_on_fluid_autosave_timeout)
	add_child(_fluid_autosave_timer)

func _on_fluid_updated() -> void:
	if _is_loading:
		return
	_fluid_autosave_timer.start(FLUID_AUTOSAVE_DELAY)

func _on_fluid_autosave_timeout() -> void:
	_do_save()

func _on_building_changed(_grid_pos: Vector2i) -> void:
	if _is_loading:
		return
	if not _save_pending:
		_save_pending = true
		_do_save.call_deferred()

func _do_save() -> void:
	_save_pending = false
	save_buildings()

func _sync_container_data() -> void:
	if not building_manager:
		return
	for grid_pos in building_manager.buildings.keys():
		var node := building_manager.get_building_node(grid_pos)
		var data: BuildingData = building_manager.buildings[grid_pos]
		if "capacity" in node:
			data.capacity = node.capacity
		if "max_capacity" in node:
			data.max_capacity = node.max_capacity

func save_buildings() -> void:
	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	_sync_container_data()

	var buildings_data: Dictionary = building_manager.get_all_buildings_data()
	var save_dict := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"buildings": {}
	}

	for grid_pos in buildings_data.keys():
		var data: BuildingData = buildings_data[grid_pos]
		var key := "%d,%d" % [grid_pos.x, grid_pos.y]
		var entry := {
			"type": data.building_type
		}
		if BuildingData.has_capacity(data.building_type):
			entry["capacity"] = data.capacity
			entry["max_capacity"] = data.max_capacity
		save_dict.buildings[key] = entry

	var dir_path := GameConfig.save_file_path.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_error("SaveManager: 无法创建存档目录: %s" % dir_path)
		return

	var temp_path := GameConfig.save_file_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()
		DirAccess.rename_absolute(temp_path, GameConfig.save_file_path)
	else:
		push_error("SaveManager: 无法写入存档文件: %s" % GameConfig.save_file_path)

func load_buildings() -> void:
	if not FileAccess.file_exists(GameConfig.save_file_path):
		EventBus.buildings_loaded.emit()
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

	_is_loading = true
	building_manager.clear_all_buildings()

	if save_data.has("buildings") and save_data.buildings is Dictionary:
		for key in save_data.buildings.keys():
			var parts: PackedStringArray = key.split(",")
			if parts.size() == 2:
				var grid_pos := Vector2i(int(parts[0]), int(parts[1]))
				var b_data: Dictionary = save_data.buildings[key]
				var b_type: String = b_data.get("type", "default")
				building_manager.place_building(grid_pos, b_type)
				if BuildingData.has_capacity(b_type) and building_manager.buildings.has(grid_pos):
					var data: BuildingData = building_manager.buildings[grid_pos]
					data.capacity = b_data.get("capacity", 0)
					data.max_capacity = b_data.get("max_capacity", data.max_capacity)
					var node := building_manager.get_building_node(grid_pos)
					if "capacity" in node:
						node.capacity = data.capacity
					if "max_capacity" in node:
						node.max_capacity = data.max_capacity

	for grid_pos in building_manager.buildings.keys():
		var node := building_manager.get_building_node(grid_pos)
		if node is PipeNode:
			node.refresh_connections()

	_is_loading = false
	EventBus.buildings_loaded.emit()
