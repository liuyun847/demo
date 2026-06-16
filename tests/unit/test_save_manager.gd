extends GutTest

var _bm: BuildingManager = null
var _sm: Node = null
var _original_save_path: String = ""
const SaveManagerScript := preload("res://scripts/persistence/save_manager.gd")


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.pipe_type_id):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.pipe_type_id,      {"is_pipe": true}],
		[GameConfig.emitter_type_id,   {"is_emitter": true}],
		[GameConfig.collector_type_id, {"is_collector": true}],
		[GameConfig.brick_type_id,     {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		types.append(td)
	BuildingTypeManager.register_all(types)


func before_each() -> void:
	_original_save_path = GameConfig.save_file_path
	GameConfig.save_file_path = "res://save/test_buildings.json"
	_cleanup_test_file()

	_bm = autoqfree(BuildingManager.new())
	_bm.name = "BuildingManager"
	var pr: PipeRenderSystem = autoqfree(preload("res://scripts/building/pipe_render_system.gd").new())
	pr.name = "PipeRenderSystem"
	_bm.add_child(pr)
	add_child_autoqfree(_bm)

	_sm = autoqfree(SaveManagerScript.new())
	add_child_autoqfree(_sm)
	_sm.building_manager = _bm

func after_each() -> void:
	GameConfig.save_file_path = _original_save_path
	_cleanup_test_file()

func _cleanup_test_file() -> void:
	if FileAccess.file_exists(GameConfig.save_file_path):
		DirAccess.remove_absolute(GameConfig.save_file_path)
	var tmp_path: String = GameConfig.save_file_path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)


func test_save_no_buildings() -> void:
	_sm.save_buildings()
	assert_true(FileAccess.file_exists(GameConfig.save_file_path), "即使无建筑也应创建存档文件")

func test_save_with_buildings() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(5, 6), GameConfig.pipe_type_id)
	_sm.save_buildings()
	var content: Dictionary = _read_save_file()
	assert_not_null(content, "存档文件应为有效 JSON")
	assert_true(content.has("version"), "应包含 version 字段")
	assert_true(content.has("buildings"), "应包含 buildings 字段")

func test_save_atomic_write() -> void:
	_sm.save_buildings()
	var tmp_path: String = GameConfig.save_file_path + ".tmp"
	assert_false(FileAccess.file_exists(tmp_path), "临时文件应已被删除或重命名")

func test_load_file_not_exists_does_not_crash() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	DirAccess.remove_absolute(GameConfig.save_file_path)
	var build_count_before: int = _bm.buildings.size()
	_sm.load_buildings()
	assert_eq(_bm.buildings.size(), build_count_before, "文件不存在时加载后建筑数量应不变")

func test_load_restores_buildings() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(5, 6), GameConfig.pipe_type_id)
	_sm.save_buildings()
	_bm.clear_all_buildings()
	assert_false(_bm.has_building(Vector2i(5, 5)), "清除后应无建筑")
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(5, 5)), "加载后应恢复建筑 (5,5)")
	assert_true(_bm.has_building(Vector2i(5, 6)), "加载后应恢复建筑 (5,6)")

func test_save_load_roundtrip() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(5, 6), GameConfig.pipe_type_id)
	_sm.save_buildings()
	var data_before: Dictionary = _bm.get_all_buildings_data().duplicate(true)
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data_after: Dictionary = _bm.get_all_buildings_data()
	assert_eq(data_before.size(), data_after.size(), "往返后建筑数量应一致")
	for grid_pos: Vector2i in data_before:
		assert_true(data_after.has(grid_pos), "往返后应包含建筑 (%d, %d)" % [grid_pos.x, grid_pos.y])
		assert_eq(data_after[grid_pos].building_type, data_before[grid_pos].building_type, "往返后建筑类型应一致")

func test_loading_does_not_trigger_save() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data: Dictionary = _bm.get_all_buildings_data()
	assert_eq(data.size(), 5, "加载后应有 5 个建筑（核心 4 格 + 1 个管道）")

func test_debounce_prevents_double_save() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	DirAccess.remove_absolute(GameConfig.save_file_path)
	assert_false(FileAccess.file_exists(GameConfig.save_file_path), "开始前存档文件不应存在")
	_sm._on_building_changed(Vector2i(5, 5))
	assert_true(_sm._save_pending, "第一次调用后 _save_pending 应为 true")
	_sm._on_building_changed(Vector2i(1, 1))
	assert_true(_sm._save_pending, "第二次调用时 _save_pending 仍应为 true（未执行保存）")
	await get_tree().process_frame
	assert_false(_sm._save_pending, "call_deferred 执行后 _save_pending 应为 false")
	assert_true(FileAccess.file_exists(GameConfig.save_file_path), "debounce 后应保存了一次")


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(GameConfig.save_file_path):
		return {}
	var file := FileAccess.open(GameConfig.save_file_path, FileAccess.READ)
	if not file:
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	return {}
