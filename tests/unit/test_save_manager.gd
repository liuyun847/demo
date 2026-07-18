extends GutTest

const FileIOHelper := preload("res://scripts/utils/file_io_helper.gd")

var _bm: BuildingManager = null
var _sm: Node = null
var _original_save_path: String = ""
const SaveManagerScript := preload("res://scripts/persistence/save_manager.gd")


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.PIPE_TYPE_ID):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.PIPE_TYPE_ID,      {"category": BuildingTypeData.Category.PIPE}],
		[GameConfig.SOURCE_TYPE_ID,    {"category": BuildingTypeData.Category.SOURCE}],
		[GameConfig.COLLECTOR_TYPE_ID, {"category": BuildingTypeData.Category.COLLECTOR}],
		[GameConfig.BRICK_TYPE_ID,     {}],
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
	_original_save_path = GameConfig.unified_save_path
	GameConfig.unified_save_path = "res://save/test_game.cfg"
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
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	_bm.place_building(Vector2i(5, 6), GameConfig.PIPE_TYPE_ID)
	_sm.save_buildings()
	var content: Dictionary = _read_save_file()
	assert_not_null(content, "存档文件应为有效 .cfg [buildings] section")
	assert_true(content.has("version"), "应包含 version 字段")
	assert_true(content.has("buildings"), "应包含 buildings 字段")

func test_save_atomic_write() -> void:
	_sm.save_buildings()
	var tmp_path: String = GameConfig.unified_save_path + ".tmp"
	assert_false(FileAccess.file_exists(tmp_path), "临时文件应已被删除或重命名")

func test_load_file_not_exists_does_not_crash() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	DirAccess.remove_absolute(GameConfig.unified_save_path)
	var build_count_before: int = _bm.buildings.size()
	_sm.load_buildings()
	assert_eq(_bm.buildings.size(), build_count_before, "文件不存在时加载后建筑数量应不变")

func test_load_restores_buildings() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	_bm.place_building(Vector2i(5, 6), GameConfig.PIPE_TYPE_ID)
	_sm.save_buildings()
	_bm.clear_all_buildings()
	assert_false(_bm.has_building(Vector2i(5, 5)), "清除后应无建筑")
	_sm.load_buildings()
	assert_true(_bm.has_building(Vector2i(5, 5)), "加载后应恢复建筑 (5,5)")
	assert_true(_bm.has_building(Vector2i(5, 6)), "加载后应恢复建筑 (5,6)")

func test_save_load_roundtrip() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	_bm.place_building(Vector2i(5, 6), GameConfig.PIPE_TYPE_ID)
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
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data: Dictionary = _bm.get_all_buildings_data()
	assert_eq(data.size(), 5, "加载后应有 5 个建筑（核心 4 格 + 1 个管道）")

func test_debounce_prevents_double_save() -> void:
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	DirAccess.remove_absolute(GameConfig.unified_save_path)
	assert_false(FileAccess.file_exists(GameConfig.unified_save_path), "开始前存档文件不应存在")
	_sm._on_building_changed(Vector2i(5, 5))
	assert_true(_sm._save_pending, "第一次调用后 _save_pending 应为 true")
	_sm._on_building_changed(Vector2i(1, 1))
	assert_true(_sm._save_pending, "第二次调用时 _save_pending 仍应为 true（未执行保存）")
	await get_tree().process_frame
	assert_false(_sm._save_pending, "call_deferred 执行后 _save_pending 应为 false")
	assert_true(FileAccess.file_exists(GameConfig.unified_save_path), "debounce 后应保存了一次")


func test_roundtrip_all_building_types() -> void:
	# 放置所有类型的建筑
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	_bm.place_building(Vector2i(6, 5), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(Vector2i(7, 5), GameConfig.SOURCE_TYPE_ID)
	_bm.place_building(Vector2i(8, 5), GameConfig.COLLECTOR_TYPE_ID)

	# 为源头设置元素类型，为收集器设置筛选
	var source_node: SourceNode = _bm.get_building_node(Vector2i(7, 5)) as SourceNode
	assert_not_null(source_node, "源头节点应存在")
	source_node.set_element_type("water")
	var collector_node: CollectorNode = _bm.get_building_node(Vector2i(8, 5)) as CollectorNode
	assert_not_null(collector_node, "收集器节点应存在")
	collector_node.set_filter("fire")

	_sm.save_buildings()
	var save_content := _read_save_file()
	assert_not_null(save_content, "存档文件应为有效 .cfg [buildings] section")
	assert_true(save_content.has("buildings"), "应包含 buildings 字段")

	# 验证存档内容正确
	var saved_buildings: Dictionary = save_content.buildings
	assert_true(saved_buildings.has("5,5"), "应保存管道 (5,5)")
	assert_true(saved_buildings.has("6,5"), "应保存砖块 (6,5)")
	assert_true(saved_buildings.has("7,5"), "应保存源头 (7,5)")
	assert_true(saved_buildings.has("8,5"), "应保存收集器 (8,5)")
	assert_eq(saved_buildings["5,5"]["type"], GameConfig.PIPE_TYPE_ID, "管道类型应正确")
	assert_eq(saved_buildings["6,5"]["type"], GameConfig.BRICK_TYPE_ID, "砖块类型应正确")
	assert_eq(saved_buildings["7,5"]["type"], GameConfig.SOURCE_TYPE_ID, "源头类型应正确")
	assert_eq(saved_buildings["8,5"]["type"], GameConfig.COLLECTOR_TYPE_ID, "收集器类型应正确")

	# 验证源头的元素类型
	assert_eq(saved_buildings["7,5"]["element_type_id"], "water", "源头元素类型应正确")
	# 验证收集器的筛选
	assert_eq(saved_buildings["8,5"]["collector_filter"], "fire", "收集器筛选应正确")

	# 非源头不应有 element_type_id；非收集器不应有 collector_filter
	assert_false(saved_buildings["5,5"].has("element_type_id"), "管道不应有 element_type_id")
	assert_false(saved_buildings["6,5"].has("element_type_id"), "砖块不应有 element_type_id")
	assert_false(saved_buildings["8,5"].has("element_type_id"), "收集器不应有 element_type_id")
	assert_false(saved_buildings["5,5"].has("collector_filter"), "管道不应有 collector_filter")
	assert_false(saved_buildings["6,5"].has("collector_filter"), "砖块不应有 collector_filter")
	assert_false(saved_buildings["7,5"].has("collector_filter"), "源头不应有 collector_filter")


func test_roundtrip_source_preserves_type() -> void:
	# 放置源头并设置自定义元素类型
	_bm.place_building(Vector2i(3, 3), GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(Vector2i(3, 3)) as SourceNode
	assert_not_null(source_node, "源头节点应存在")
	source_node.set_element_type("water")

	# 保存 → 重载 → 验证
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data_after: Dictionary = _bm.get_all_buildings_data()

	assert_true(data_after.has(Vector2i(3, 3)), "重载后源头应存在")
	var after_type: String = data_after[Vector2i(3, 3)].building_type
	assert_eq(after_type, GameConfig.SOURCE_TYPE_ID, "源头类型应保留")

	# 从节点验证属性
	var loaded_source: SourceNode = _bm.get_building_node(Vector2i(3, 3)) as SourceNode
	assert_not_null(loaded_source, "重载后源头节点应存在")
	assert_eq(loaded_source.element_type_id, "water", "源头元素类型应保留")
	assert_true(loaded_source.has_type_selected(), "重载后源头应标记为已确认类型")


func test_roundtrip_collector_preserves_filter() -> void:
	# 放置收集器并设置筛选
	_bm.place_building(Vector2i(4, 4), GameConfig.COLLECTOR_TYPE_ID)
	var collector_node: CollectorNode = _bm.get_building_node(Vector2i(4, 4)) as CollectorNode
	assert_not_null(collector_node, "收集器节点应存在")
	collector_node.set_filter("water")

	# 保存 → 重载 → 验证
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data_after: Dictionary = _bm.get_all_buildings_data()

	assert_true(data_after.has(Vector2i(4, 4)), "重载后收集器应存在")
	var after_type: String = data_after[Vector2i(4, 4)].building_type
	assert_eq(after_type, GameConfig.COLLECTOR_TYPE_ID, "收集器类型应保留")

	# 从节点验证筛选保留
	var loaded_collector: CollectorNode = _bm.get_building_node(Vector2i(4, 4)) as CollectorNode
	assert_not_null(loaded_collector, "重载后收集器节点应存在")
	assert_eq(loaded_collector.filter_element_type, "water", "收集器筛选应保留")


func test_no_building_type_replaced_after_save() -> void:
	# 模拟连续多次自动保存，验证没有建筑类型被替换
	_bm.place_building(Vector2i(1, 1), GameConfig.PIPE_TYPE_ID)
	_bm.place_building(Vector2i(2, 2), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(Vector2i(3, 3), GameConfig.SOURCE_TYPE_ID)
	_bm.place_building(Vector2i(4, 4), GameConfig.COLLECTOR_TYPE_ID)

	var expected_types := {
		Vector2i(1, 1): GameConfig.PIPE_TYPE_ID,
		Vector2i(2, 2): GameConfig.BRICK_TYPE_ID,
		Vector2i(3, 3): GameConfig.SOURCE_TYPE_ID,
		Vector2i(4, 4): GameConfig.COLLECTOR_TYPE_ID,
	}

	# 模拟 5 次自动保存（通过信号触发）
	for i in range(5):
		_sm._on_building_changed(Vector2i(1, 1))
		await get_tree().process_frame

		# 每次保存后验证所有建筑类型不变
		for pos: Vector2i in expected_types.keys():
			var actual: String = _bm.get_building_type(pos)
			assert_eq(actual, expected_types[pos],
				"建筑 (%d,%d) 类型不应被替换: 期望 %s, 实际 %s" % [pos.x, pos.y, expected_types[pos], actual])


func test_load_does_not_alter_building_types() -> void:
	# 保存包含多种建筑的类型
	_bm.place_building(Vector2i(2, 3), GameConfig.PIPE_TYPE_ID)
	_bm.place_building(Vector2i(4, 5), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(Vector2i(6, 7), GameConfig.SOURCE_TYPE_ID)

	_sm.save_buildings()

	# 重载
	_bm.clear_all_buildings()
	assert_false(_bm.has_building(Vector2i(2, 3)), "清除后建筑应不存在")
	_sm.load_buildings()

	# 验证所有非核心建筑类型正确
	assert_true(_bm.has_building(Vector2i(2, 3)), "加载后管道应存在")
	assert_true(_bm.has_building(Vector2i(4, 5)), "加载后砖块应存在")
	assert_true(_bm.has_building(Vector2i(6, 7)), "加载后源头应存在")
	assert_eq(_bm.get_building_type(Vector2i(2, 3)), GameConfig.PIPE_TYPE_ID, "管道类型应正确")
	assert_eq(_bm.get_building_type(Vector2i(4, 5)), GameConfig.BRICK_TYPE_ID, "砖块类型应正确")
	assert_eq(_bm.get_building_type(Vector2i(6, 7)), GameConfig.SOURCE_TYPE_ID, "源头类型应正确")

	# 不应对核心产生影响
	assert_true(_bm.has_building(Vector2i(-1, -1)), "核心 (-1,-1) 应存在")
	assert_true(_bm.has_building(Vector2i(0, 0)), "核心 (0,0) 应存在")


## 旧存档兼容性测试：包含 output_direction 字段的存档应被静默忽略
## 历史问题：旧版本源头（emitter）有方向概念，新版本源头已移除方向，需兼容旧存档
func test_load_legacy_save_with_output_direction_ignored() -> void:
	# 构造旧存档：源头携带 output_direction 字段
	var save_data := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": "2026-01-01T00:00:00",
		"essence": 50.0,
		"buildings": {
			"3,3": {
				"type": GameConfig.SOURCE_TYPE_ID,
				"output_direction": [0, -1],
				"element_type_id": "water",
			},
			"5,5": {
				"type": GameConfig.PIPE_TYPE_ID,
			},
		},
	}
	_write_save_file(save_data)

	# 加载应成功，output_direction 被忽略
	_sm.load_buildings()

	assert_true(_bm.has_building(Vector2i(3, 3)), "源头应被加载")
	assert_true(_bm.has_building(Vector2i(5, 5)), "管道应被加载")
	var source_node: SourceNode = _bm.get_building_node(Vector2i(3, 3)) as SourceNode
	assert_not_null(source_node, "源头节点应存在")
	assert_eq(source_node.element_type_id, "water", "element_type_id 应被加载")
	assert_false("output_direction" in source_node, "SourceNode 不应持有 output_direction 属性")
	# 验证 SourceNode 没有 set_output_direction 方法（旧 API 已移除）
	assert_false(source_node.has_method("set_output_direction"), "SourceNode 不应有 set_output_direction 方法")


## 旧存档兼容性测试：未设置 collector_filter 的收集器应默认空筛选（收全部）
func test_load_legacy_collector_without_filter_defaults_empty() -> void:
	var save_data := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": "2026-01-01T00:00:00",
		"essence": 50.0,
		"buildings": {
			"4,4": {
				"type": GameConfig.COLLECTOR_TYPE_ID,
				# 旧存档没有 collector_filter 字段
			},
		},
	}
	_write_save_file(save_data)

	_sm.load_buildings()

	assert_true(_bm.has_building(Vector2i(4, 4)), "收集器应被加载")
	var collector_node: CollectorNode = _bm.get_building_node(Vector2i(4, 4)) as CollectorNode
	assert_not_null(collector_node, "收集器节点应存在")
	assert_eq(collector_node.filter_element_type, "", "无 collector_filter 字段时应默认空筛选（收全部）")


func test_save_does_not_mutate_node_state() -> void:
	# 验证 save 操作不会改变节点的 visible/position 等状态
	_bm.place_building(Vector2i(5, 5), GameConfig.PIPE_TYPE_ID)
	var pipe_node: PipeNode = _bm.get_building_node(Vector2i(5, 5)) as PipeNode
	assert_not_null(pipe_node, "管道节点应存在")

	var original_pos: Vector2 = pipe_node.global_position
	var original_visible: bool = pipe_node.visible

	# 执行多次保存
	for _i in range(3):
		_sm.save_buildings()

	assert_eq(pipe_node.global_position, original_pos, "保存不应改变建筑位置")
	assert_eq(pipe_node.visible, original_visible, "保存不应改变建筑可见性")


func test_load_essence_int_type() -> void:
	# 保存原始 essence 值，避免影响其他测试
	var original_essence: float = EssencePool.essence
	# 写入包含 int 类型 essence 的存档文件（JSON 中 100 为 int，100.0 为 float）
	var save_data := {
		"version": GameConfig.SAVE_VERSION,
		"saved_at": "2026-01-01T00:00:00",
		"essence": 100,
		"buildings": {}
	}
	_write_save_file(save_data)
	EssencePool.set_value(0.0)
	_sm.load_buildings()
	# load_buildings 应通过 float() 将 int 类型的 essence 转换为 float
	assert_eq(EssencePool.essence, 100.0, "int 类型的 essence 应正确加载为 float 100.0")
	# 恢复原始值，避免影响其他测试
	EssencePool.set_value(original_essence)


func test_save_write_failure_does_not_crash() -> void:
	# 使用包含非法字符的路径触发写入失败（Windows 不允许 ? 在文件名中）
	GameConfig.unified_save_path = "res://save/invalid?name.cfg"
	_sm.save_buildings()
	# 应触发 push_error 但不崩溃
	assert_push_error("无法写入文件", "FileIOHelper 应 push_error 无法写入文件")
	assert_push_error("存档写入失败", "SaveManager 应 push_error 存档写入失败")


func _read_save_file() -> Dictionary:
	# 读取 .cfg 的 [buildings] section 并返回为 Dictionary
	if not FileIOHelper.cfg_has_section(GameConfig.unified_save_path, GameConfig.SECTION_BUILDINGS):
		return {}
	var result := FileIOHelper.read_cfg_section(
		GameConfig.unified_save_path,
		GameConfig.SECTION_BUILDINGS,
		"TestSaveManager"
	)
	if result.success:
		return result.data
	return {}


func _write_save_file(data: Dictionary) -> void:
	# 直接写入 .cfg 的 [buildings] section（用于构造测试用的存档数据）
	FileIOHelper.write_cfg_section(
		GameConfig.unified_save_path,
		GameConfig.SECTION_BUILDINGS,
		data,
		"TestSaveManager"
	)
