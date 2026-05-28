class_name SaveManager
extends Node

@onready var building_manager: BuildingManager = (
	get_node("%BuildingManager") if has_node("%BuildingManager") else get_node("../BuildingManager")
) as BuildingManager

var _is_loading: bool = false
var _save_pending: bool = false

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)
	load_buildings()

func _exit_tree() -> void:
	if EventBus.building_placed.is_connected(_on_building_changed):
		EventBus.building_placed.disconnect(_on_building_changed)
	if EventBus.building_removed.is_connected(_on_building_changed):
		EventBus.building_removed.disconnect(_on_building_changed)

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
	for grid_pos: Vector2i in building_manager.buildings.keys():
		var data: BuildingData = building_manager.buildings[grid_pos]
		var node := building_manager.get_building_node(grid_pos)
		if node:
			BuildingData.sync_capacity_from_node(data, node)

func save_buildings() -> void:
	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	var save_dict := _build_save_dict()

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
		var rename_err := DirAccess.rename_absolute(temp_path, GameConfig.save_file_path)
		if rename_err != OK:
			push_error("SaveManager: 无法重命名临时文件，错误码: %d" % rename_err)
			DirAccess.remove_absolute(temp_path)
	else:
		push_error("SaveManager: 无法写入存档文件: %s" % GameConfig.save_file_path)

func _build_save_dict() -> Dictionary:
	var save_dict := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"essence": EssencePool.essence,
		"buildings": {}
	}

	for grid_pos: Vector2i in building_manager.buildings.keys():
		var data: BuildingData = building_manager.buildings[grid_pos]

		if BuildingData.has_capacity(data.building_type):
			var node := building_manager.get_building_node(grid_pos)
			if node:
				BuildingData.sync_capacity_from_node(data, node)

		if BuildingData.is_emitter(data.building_type):
			var node := building_manager.get_building_node(grid_pos)
			if node:
				BuildingData.sync_emitter_type_from_node(data, node)

		var key := "%d,%d" % [grid_pos.x, grid_pos.y]
		var entry := {
			"type": data.building_type
		}
		if BuildingData.has_capacity(data.building_type):
			entry["capacity"] = data.capacity
			entry["max_capacity"] = data.max_capacity
		if BuildingData.is_emitter(data.building_type):
			if not data.element_type_id.is_empty():
				entry["element_type_id"] = data.element_type_id
			entry["output_direction"] = [data.output_direction.x, data.output_direction.y]
		save_dict.buildings[key] = entry

	return save_dict

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

	var save_data: Dictionary = JSON.parse_string(content) as Dictionary
	if save_data == null or not save_data is Dictionary:
		push_error("SaveManager: 存档格式无效")
		return

	if not save_data.has("version"):
		push_error("SaveManager: 存档缺少版本号")
		return

	if save_data.version != GameConfig.SAVE_VERSION:
		push_warning("SaveManager: 存档版本不匹配，期望 %s，实际 %s" % [GameConfig.SAVE_VERSION, save_data.version])
		var backup_path := GameConfig.save_file_path.replace(".json", "_v%s.json.bak" % save_data.version)
		var backup_err := DirAccess.copy_absolute(GameConfig.save_file_path, backup_path)
		if backup_err == OK:
			push_warning("SaveManager: 已备份旧存档到: %s" % backup_path)
		else:
			push_warning("SaveManager: 无法备份旧存档（错误码: %d），将直接忽略" % backup_err)
		EventBus.buildings_loaded.emit()
		return

	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	_is_loading = true
	building_manager.bulk_clear()

	if save_data.has("essence") and save_data.essence is float:
		EssencePool.set_value(save_data.essence)

	if save_data.has("buildings") and save_data.buildings is Dictionary:
		for key: String in save_data.buildings.keys():
			var parts: PackedStringArray = key.split(",")
			if parts.size() == 2:
				if not parts[0].is_valid_int() or not parts[1].is_valid_int():
					push_warning("SaveManager: 无效的格子坐标: %s，跳过" % key)
					continue
				var grid_pos: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
				var b_data: Variant = save_data.buildings[key]
				if not b_data is Dictionary:
					push_warning("SaveManager: 建筑数据格式无效，跳过: %s" % key)
					continue
				var b_type: String = b_data.get("type", "default")
				var restore_data: Dictionary = {}
				if BuildingData.has_capacity(b_type):
					restore_data["capacity"] = b_data.get("capacity", 0)
					restore_data["max_capacity"] = b_data.get("max_capacity", 100)
				if BuildingData.is_emitter(b_type):
					if b_data.has("element_type_id"):
						restore_data["element_type_id"] = b_data["element_type_id"]
					if b_data.has("output_direction"):
						restore_data["output_direction"] = b_data["output_direction"]
				building_manager.place_building(grid_pos, b_type, restore_data)

	call_deferred("_finalize_loading")

func _finalize_loading() -> void:
	for grid_pos: Vector2i in building_manager.buildings.keys():
		var node := building_manager.get_building_node(grid_pos)
		if node is PipeNode:
			node.refresh_connections(building_manager.is_pipe_or_buffer_at)
		elif node is ContainerNode:
			node.queue_redraw()

	_is_loading = false
	EventBus.buildings_loaded.emit()
