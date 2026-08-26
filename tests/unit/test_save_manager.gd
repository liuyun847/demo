extends GutTest

const FileIOHelper := preload("res://scripts/utils/file_io_helper.gd")

var _bm: BuildingManager = null
var _sm: Node = null
var _original_save_path: String = ""
const SaveManagerScript := preload("res://scripts/persistence/save_manager.gd")


func before_all() -> void:
	BuildingTypeManager.register_defaults()


func before_each() -> void:
	_original_save_path = GameConfig.unified_save_path
	GameConfig.unified_save_path = "res://save/test_game.cfg"
	_cleanup_test_file()

	_bm = autoqfree(BuildingManager.new())
	_bm.name = "BuildingManager"
	add_child_autoqfree(_bm)

	_sm = autoqfree(SaveManagerScript.new())
	add_child_autoqfree(_sm)
	_sm.building_manager = _bm

func after_each() -> void:
	# 先清理测试文件（此时 unified_save_path 仍是测试路径），再恢复原路径
	# 顺序很重要：若先恢复原路径，_cleanup_test_file 会误删开发存档 game.cfg
	_cleanup_test_file()
	GameConfig.unified_save_path = _original_save_path

func _cleanup_test_file() -> void:
	if FileAccess.file_exists(GameConfig.unified_save_path):
		DirAccess.remove_absolute(GameConfig.unified_save_path)
	var tmp_path: String = GameConfig.unified_save_path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)


func test_save_no_buildings() -> void:
	_sm.save_buildings()
	assert_true(FileAccess.file_exists(GameConfig.unified_save_path), "即使无建筑也应创建存档文件")

func test_save_with_buildings() -> void:
	_bm.place_building(Vector2i(5, 5), MachineSpec.T_BELT)
	_bm.place_building(Vector2i(5, 6), MachineSpec.T_NUM_SOURCE)
	_sm.save_buildings()
	var content: Dictionary = _read_save_file()
	assert_not_null(content, "存档文件应为有效 .cfg [buildings] section")
	assert_true(content.has("version"), "应包含 version 字段")
	assert_eq(content.buildings.size(), 2, "应保存 2 个建筑")

func test_save_roundtrip_belt_direction() -> void:
	_bm.place_building(Vector2i(3, 3), MachineSpec.T_BELT, {"direction": MachineSpec.DIR_N})
	_sm.save_buildings()
	# 重新加载
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(3, 3)), "重载后建筑应存在")
	var data: BuildingData = _bm.get_building_data(Vector2i(3, 3))
	assert_eq(data.building_type, MachineSpec.T_BELT)
	assert_eq(data.direction, MachineSpec.DIR_N, "传送带朝向应还原")

func test_save_roundtrip_machine_fields() -> void:
	_bm.place_building(Vector2i(4, 4), MachineSpec.T_APPLIER, {
		"direction": MachineSpec.DIR_S,
		"op_choice": OpRegistry.OP_MUL2,
	})
	_bm.place_building(Vector2i(6, 6), MachineSpec.T_FILTER, {
		"direction": MachineSpec.DIR_W,
		"filter_kind": "num",
		"filter_cmp": "eq",
		"filter_value": 5,
	})
	_bm.place_building(Vector2i(2, 2), MachineSpec.T_SPLITTER, {"splitter_phase": 1})
	_sm.save_buildings()
	_sm.load_buildings()
	var op_data: BuildingData = _bm.get_building_data(Vector2i(4, 4))
	assert_eq(op_data.direction, MachineSpec.DIR_S, "应用器朝向应还原")
	assert_eq(op_data.op_choice, OpRegistry.OP_MUL2, "操作选择应还原")
	var filter_data: BuildingData = _bm.get_building_data(Vector2i(6, 6))
	assert_eq(filter_data.direction, MachineSpec.DIR_W, "筛选器朝向应还原")
	assert_eq(filter_data.filter_cmp, "eq", "筛选比较应还原")
	assert_eq(filter_data.filter_value, 5, "筛选值应还原")
	var split_data: BuildingData = _bm.get_building_data(Vector2i(2, 2))
	assert_eq(split_data.splitter_phase, 1, "分流交替位应还原")

func test_save_roundtrip_belt_splitter() -> void:
	# 传送带+分流器一体建筑往返：类型/方向/交替位完整还原
	_bm.place_building(Vector2i(1, 1), MachineSpec.T_BELT_SPLITTER, {
		"direction": MachineSpec.DIR_W,
		"splitter_phase": 1,
	})
	_sm.save_buildings()
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(1, 1)), "重载后一体建筑应存在")
	var data: BuildingData = _bm.get_building_data(Vector2i(1, 1))
	assert_eq(data.building_type, MachineSpec.T_BELT_SPLITTER, "类型应还原")
	assert_eq(data.direction, MachineSpec.DIR_W, "朝向应还原")
	assert_eq(data.splitter_phase, 1, "交替位应还原")

func test_save_roundtrip_composite_op_choice() -> void:
	# 回归：复合操作 id 是会话内递增的，重载后旧 id 失效；
	# 存档携带定义串，跨会话恢复后仍应产出语义一致的操作
	# （op_choice 字段保留为通用容器，用应用器验证落盘）
	var comp := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	_bm.place_building(Vector2i(7, 7), MachineSpec.T_APPLIER, {"op_choice": comp})
	_sm.save_buildings()
	var content: Dictionary = _read_save_file()
	var saved_entry: Dictionary = content.buildings["7,7"]
	assert_true(saved_entry.has("op_def"), "复合操作应落盘定义串")
	# 模拟新会话：清空操作注册表后重载
	OpRegistry.reset()
	_sm.load_buildings()
	var data: BuildingData = _bm.get_building_data(Vector2i(7, 7))
	assert_true(OpRegistry.has(data.op_choice), "重载后操作 id 应有效（已按定义重建）")
	assert_eq(OpRegistry.apply(data.op_choice, 3), 8, "重建后语义一致：先 +1 再 ×2")

func test_save_roundtrip_filter_op_definition() -> void:
	var comp := OpRegistry.compose(OpRegistry.OP_SUB1, OpRegistry.OP_NEG)
	_bm.place_building(Vector2i(8, 8), MachineSpec.T_FILTER, {
		"filter_kind": "op",
		"filter_cmp": "eq",
		"filter_value": comp,
	})
	_sm.save_buildings()
	var content: Dictionary = _read_save_file()
	assert_true(content.buildings["8,8"].has("filter_op_def"), "op 筛选应落盘定义串")
	OpRegistry.reset()
	_sm.load_buildings()
	var data: BuildingData = _bm.get_building_data(Vector2i(8, 8))
	assert_eq(data.filter_kind, "op")
	assert_true(OpRegistry.has(data.filter_value), "重载后筛选操作 id 应有效")
	assert_eq(OpRegistry.apply(data.filter_value, 4), -3, "重建后筛选语义一致：先 -1 得 3，再取反得 -3")

func test_save_load_unknown_type_skipped() -> void:
	# 直接注入旧版/未知类型存档，加载应跳过不崩溃
	var entries := {
		"5,5": {"type": "type_02"},
		"6,6": {"type": MachineSpec.T_BELT},
		"7,7": {"type": "totally_unknown"},
	}
	var save_data := {
		"version": GameConfig.SAVE_VERSION,
		"buildings": entries,
	}
	FileIOHelper.write_cfg_section(GameConfig.unified_save_path, GameConfig.SECTION_BUILDINGS, save_data, "SaveManager")
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(6, 6)), "已知类型应加载")
	assert_false(_bm.has_building(Vector2i(5, 5)), "未知类型应跳过")
	assert_false(_bm.has_building(Vector2i(7, 7)), "未知类型应跳过")

func test_load_invalid_coords_skipped() -> void:
	var entries := {
		"abc,def": {"type": MachineSpec.T_BELT},
		"1,1": {"type": MachineSpec.T_NUM_SOURCE},
	}
	var save_data := {
		"version": GameConfig.SAVE_VERSION,
		"buildings": entries,
	}
	FileIOHelper.write_cfg_section(GameConfig.unified_save_path, GameConfig.SECTION_BUILDINGS, save_data, "SaveManager")
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(1, 1)), "有效坐标应加载")
	assert_eq(_bm.get_all_buildings_data().size(), 1, "无效坐标应跳过")

func test_load_default_filter_omitted() -> void:
	# 默认筛选（数字 > 0）不落盘，加载后恢复默认
	_bm.place_building(Vector2i(6, 6), MachineSpec.T_FILTER)
	_sm.save_buildings()
	var content: Dictionary = _read_save_file()
	var entry: Dictionary = content.buildings["6,6"]
	assert_false(entry.has("filter_kind"), "默认筛选配置不应写入存档")
	_sm.load_buildings()
	var data: BuildingData = _bm.get_building_data(Vector2i(6, 6))
	assert_eq(data.filter_kind, "num", "加载后应按默认值")
	assert_eq(data.filter_cmp, "gt")

func _read_save_file() -> Dictionary:
	var result := FileIOHelper.read_cfg_section(
		GameConfig.unified_save_path,
		GameConfig.SECTION_BUILDINGS,
		"SaveManager"
	)
	if not result.success:
		return {}
	return result.data