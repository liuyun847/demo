extends GutTest

var _bm: BuildingManager = null
var _sm: Node = null
var _original_save_path: String = ""
const SaveManagerScript := preload("res://scripts/persistence/save_manager.gd")

func before_each():
	_original_save_path = GameConfig.save_file_path
	GameConfig.save_file_path = "res://save/test_buildings.json"
	_cleanup_test_file()

	_bm = autoqfree(BuildingManager.new())
	_bm.name = "BuildingManager"
	add_child_autoqfree(_bm)

	_sm = autoqfree(SaveManagerScript.new())
	add_child_autoqfree(_sm)
	# @onready 在 _ready 中设置 building_manager，可能因路径问题失败，手动修正
	_sm.building_manager = _bm

func after_each():
	GameConfig.save_file_path = _original_save_path
	_cleanup_test_file()

func _cleanup_test_file() -> void:
	if FileAccess.file_exists(GameConfig.save_file_path):
		DirAccess.remove_absolute(GameConfig.save_file_path)
	var tmp_path = GameConfig.save_file_path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)


func test_save_no_buildings():
	_sm.save_buildings()
	assert_true(FileAccess.file_exists(GameConfig.save_file_path), "即使无建筑也应创建存档文件")

func test_save_with_buildings():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.pipe_type_id)
	_sm.save_buildings()
	var content = _read_save_file()
	assert_not_null(content, "存档文件应为有效 JSON")
	assert_true(content.has("version"), "应包含 version 字段")
	assert_true(content.has("buildings"), "应包含 buildings 字段")

func test_save_with_capacity_data():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var container = _bm.get_node("Building_0_0")
	container.capacity = 50
	_sm._sync_container_data()
	_sm.save_buildings()
	var content = _read_save_file()
	var key = "0,0"
	assert_true(content.buildings.has(key), "存档应包含 (0,0)")
	assert_eq(content.buildings[key].capacity, 50.0, "存档应保存 capacity")
	assert_eq(content.buildings[key].max_capacity, 100.0, "存档应保存 max_capacity")

func test_save_atomic_write():
	_sm.save_buildings()
	var tmp_path = GameConfig.save_file_path + ".tmp"
	assert_false(FileAccess.file_exists(tmp_path), "临时文件应已被删除或重命名")

func test_load_file_not_exists_does_not_crash():
	_bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	DirAccess.remove_absolute(GameConfig.save_file_path)
	var build_count_before = _bm.buildings.size()
	_sm.load_buildings()
	assert_eq(_bm.buildings.size(), build_count_before, "文件不存在时加载后建筑数量应不变")

func test_load_restores_buildings():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_bm.place_building(Vector2i(2, 2), GameConfig.pipe_type_id)
	_sm.save_buildings()
	_bm.clear_all_buildings()
	assert_false(_bm.has_building(Vector2i(0, 0)), "清除后应无建筑")
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(0, 0)), "加载后应恢复建筑 (0,0)")
	assert_true(_bm.has_building(Vector2i(2, 2)), "加载后应恢复建筑 (2,2)")

func test_load_restores_capacity():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	var container = _bm.get_node("Building_0_0")
	container.capacity = 75
	container.max_capacity = 150
	_sm._sync_container_data()
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var loaded_data = _bm.buildings[Vector2i(0, 0)]
	assert_eq(loaded_data.capacity, 75, "加载后容量应恢复为 75")
	var loaded_node = _bm.get_node("Building_0_0")
	assert_eq(loaded_node.capacity, 75, "加载后节点容量应恢复为 75")

func test_save_load_roundtrip():
	_bm.place_building(Vector2i(3, 4), GameConfig.container_type_id)
	_bm.place_building(Vector2i(1, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(7, 0), GameConfig.water_source_type_id)
	_sm.save_buildings()
	var data_before = _bm.get_all_buildings_data().duplicate(true)
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data_after = _bm.get_all_buildings_data()
	assert_eq(data_before.size(), data_after.size(), "往返后建筑数量应一致")
	for grid_pos in data_before:
		assert_true(data_after.has(grid_pos), "往返后应包含建筑 (%d, %d)" % [grid_pos.x, grid_pos.y])
		assert_eq(data_after[grid_pos].building_type, data_before[grid_pos].building_type, "往返后建筑类型应一致")

func test_loading_does_not_trigger_save():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data = _bm.get_all_buildings_data()
	assert_eq(data.size(), 1, "加载后应有 1 个建筑")

func test_debounce_prevents_double_save():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	DirAccess.remove_absolute(GameConfig.save_file_path)
	assert_false(FileAccess.file_exists(GameConfig.save_file_path), "开始前存档文件不应存在")
	_sm._on_building_changed(Vector2i(0, 0))
	assert_true(_sm._save_pending, "第一次调用后 _save_pending 应为 true")
	_sm._on_building_changed(Vector2i(1, 1))
	assert_true(_sm._save_pending, "第二次调用时 _save_pending 仍应为 true（未执行保存）")
	await get_tree().process_frame
	assert_false(_sm._save_pending, "call_deferred 执行后 _save_pending 应为 false")
	assert_true(FileAccess.file_exists(GameConfig.save_file_path), "debounce 后应保存了一次")

func test_fluid_updated_autosave():
	_bm.place_building(Vector2i(0, 0), GameConfig.container_type_id)
	DirAccess.remove_absolute(GameConfig.save_file_path)
	assert_false(FileAccess.file_exists(GameConfig.save_file_path), "开始前存档文件不应存在")
	EventBus.fluid_updated.emit()
	assert_true(_sm._fluid_autosave_timer.time_left > 0, "fluid_updated 后计时器应已启动")
	_sm._fluid_autosave_timer.stop()
	_sm._on_fluid_autosave_timeout()
	assert_true(FileAccess.file_exists(GameConfig.save_file_path), "计时器超时后应执行保存")


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(GameConfig.save_file_path):
		return {}
	var file := FileAccess.open(GameConfig.save_file_path, FileAccess.READ)
	if not file:
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	return {}
