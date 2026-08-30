class_name SaveManager
extends Node

const FileIOHelper := preload("res://scripts/utils/file_io_helper.gd")

@onready var building_manager: BuildingManager = (
	get_node("%BuildingManager") if has_node("%BuildingManager") else get_node("../BuildingManager")
) as BuildingManager

var _is_loading: bool = false
var _save_pending: bool = false

func _ready() -> void:
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)
	EventBus.machine_config_changed.connect(_on_building_changed)
	# 延迟到所有子节点 _ready 完成后加载，避免 building_manager 未就绪
	call_deferred("load_buildings")

func _exit_tree() -> void:
	if EventBus.building_placed.is_connected(_on_building_changed):
		EventBus.building_placed.disconnect(_on_building_changed)
	if EventBus.building_removed.is_connected(_on_building_changed):
		EventBus.building_removed.disconnect(_on_building_changed)
	if EventBus.machine_config_changed.is_connected(_on_building_changed):
		EventBus.machine_config_changed.disconnect(_on_building_changed)

func _on_building_changed(_grid_pos: Vector2i) -> void:
	if _is_loading:
		return
	if not _save_pending:
		_save_pending = true
		_do_save.call_deferred()

func _do_save() -> void:
	_save_pending = false
	save_buildings()

func save_buildings() -> void:
	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	var save_dict := _build_save_dict()
	var success := FileIOHelper.write_cfg_section(
		GameConfig.unified_save_path,
		GameConfig.SECTION_BUILDINGS,
		save_dict,
		"SaveManager"
	)
	if not success:
		push_error("SaveManager: 存档写入失败，进度可能未保存")

func _build_save_dict() -> Dictionary:
	var save_dict := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"essence": EssencePool.essence,
		"buildings": {}
	}

	for grid_pos: Vector2i in building_manager.buildings.keys():
		var data: BuildingData = building_manager.buildings[grid_pos]

		# 同步节点状态到 data（朝向/操作选择/分流轮询相位/按方向过滤条件）
		var node := building_manager.get_building_node(grid_pos)
		if node:
			BuildingDataSyncService.sync_from_node(data, node)

		var key := "%d,%d" % [grid_pos.x, grid_pos.y]
		var entry := BuildingDataSyncService.data_to_entry(data)
		# 旧流体系统遗留字段（仅旧存档兼容，新系统不产生）
		if BuildingTypeManager.is_source(data.building_type) and not data.element_type_id.is_empty():
			entry["element_type_id"] = data.element_type_id
		elif BuildingTypeManager.is_collector(data.building_type) and not data.collector_filter.is_empty():
			entry["collector_filter"] = data.collector_filter
		save_dict.buildings[key] = entry

	return save_dict

func load_buildings() -> void:
	if not FileIOHelper.cfg_has_section(GameConfig.unified_save_path, GameConfig.SECTION_BUILDINGS):
		EventBus.buildings_loaded.emit()
		return

	var result := FileIOHelper.read_cfg_section(
		GameConfig.unified_save_path,
		GameConfig.SECTION_BUILDINGS,
		"SaveManager",
		GameConfig.SAVE_VERSION,
		_on_save_version_mismatch
	)

	if not result.success:
		push_warning(result.error_message)
		EventBus.buildings_loaded.emit()
		return

	if result.version_mismatch:
		push_warning(result.error_message)

	var save_data: Dictionary = result.data

	if not building_manager:
		push_error("SaveManager: 找不到 BuildingManager 节点")
		return

	_is_loading = true
	building_manager.clear_all_buildings_silent()

	if save_data.has("essence") and (save_data.essence is float or save_data.essence is int):
		EssencePool.set_value(float(save_data.essence))

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
				# 未知类型（旧流体存档/核心）跳过，不崩溃
				if not BuildingTypeManager.is_known(b_type) or b_type == GameConfig.CORE_TYPE_ID:
					continue
				var restore_data: Dictionary = BuildingDataSyncService.entry_to_restore_data(b_data)
				if BuildingTypeManager.is_source(b_type):
					if b_data.has("element_type_id"):
						restore_data["element_type_id"] = b_data["element_type_id"]
				elif BuildingTypeManager.is_collector(b_type):
					if b_data.has("collector_filter"):
						restore_data["collector_filter"] = b_data["collector_filter"]
				building_manager.place_building(grid_pos, b_type, restore_data)

	call_deferred("_finalize_loading")

func _on_save_version_mismatch(data: Dictionary, file_path: String) -> void:
	# .cfg 是统一存档文件，备份整个文件以保留所有 section 的原始状态
	var backup_path := "%s.v%s.bak" % [file_path.get_basename(), str(data.get("version", "unknown"))]
	var backup_err := DirAccess.copy_absolute(file_path, backup_path)
	if backup_err == OK:
		push_warning("SaveManager: 已备份旧存档到: %s" % backup_path)
	else:
		push_warning("SaveManager: 无法备份旧存档（错误码: %d），将直接忽略" % backup_err)

func _finalize_loading() -> void:
	_is_loading = false
	EventBus.buildings_loaded.emit()
