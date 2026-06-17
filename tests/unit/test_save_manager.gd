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


func test_roundtrip_all_building_types() -> void:
	# 放置所有类型的建筑
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(6, 5), GameConfig.brick_type_id)
	_bm.place_building(Vector2i(7, 5), GameConfig.emitter_type_id)
	_bm.place_building(Vector2i(8, 5), GameConfig.collector_type_id)

	# 为发射器设置方向和元素类型
	var emitter_node: EmitterNode = _bm.get_building_node(Vector2i(7, 5)) as EmitterNode
	assert_not_null(emitter_node, "发射器节点应存在")
	emitter_node.set_output_direction(Vector2i(-1, 0))
	emitter_node.set_element_type("water")

	_sm.save_buildings()
	var save_content := _read_save_file()
	assert_not_null(save_content, "存档文件应为有效 JSON")
	assert_true(save_content.has("buildings"), "应包含 buildings 字段")

	# 验证存档内容正确
	var saved_buildings: Dictionary = save_content.buildings
	assert_true(saved_buildings.has("5,5"), "应保存管道 (5,5)")
	assert_true(saved_buildings.has("6,5"), "应保存砖块 (6,5)")
	assert_true(saved_buildings.has("7,5"), "应保存发射器 (7,5)")
	assert_true(saved_buildings.has("8,5"), "应保存收集器 (8,5)")
	assert_eq(saved_buildings["5,5"]["type"], GameConfig.pipe_type_id, "管道类型应正确")
	assert_eq(saved_buildings["6,5"]["type"], GameConfig.brick_type_id, "砖块类型应正确")
	assert_eq(saved_buildings["7,5"]["type"], GameConfig.emitter_type_id, "发射器类型应正确")
	assert_eq(saved_buildings["8,5"]["type"], GameConfig.collector_type_id, "收集器类型应正确")

	# 验证发射器方向
	assert_eq(saved_buildings["7,5"]["output_direction"], [-1.0, 0.0], "发射器方向应正确")
	assert_eq(saved_buildings["7,5"]["element_type_id"], "water", "发射器元素类型应正确")

	# 非发射器不应有 output_direction / element_type_id
	assert_false(saved_buildings["5,5"].has("output_direction"), "管道不应有 output_direction")
	assert_false(saved_buildings["6,5"].has("output_direction"), "砖块不应有 output_direction")
	assert_false(saved_buildings["8,5"].has("output_direction"), "收集器不应有 output_direction")


func test_roundtrip_emitter_preserves_direction_and_type() -> void:
	# 放置发射器并设置自定义方向/类型
	_bm.place_building(Vector2i(3, 3), GameConfig.emitter_type_id)
	var emitter_node: EmitterNode = _bm.get_building_node(Vector2i(3, 3)) as EmitterNode
	assert_not_null(emitter_node, "发射器节点应存在")
	emitter_node.set_output_direction(Vector2i(0, -1))
	emitter_node.set_element_type("water")

	# 保存 → 重载 → 验证
	_sm.save_buildings()
	_bm.clear_all_buildings()
	_sm.load_buildings()
	var data_after: Dictionary = _bm.get_all_buildings_data()

	assert_true(data_after.has(Vector2i(3, 3)), "重载后发射器应存在")
	var after_type: String = data_after[Vector2i(3, 3)].building_type
	assert_eq(after_type, GameConfig.emitter_type_id, "发射器类型应保留")

	# 从节点验证属性
	var loaded_emitter: EmitterNode = _bm.get_building_node(Vector2i(3, 3)) as EmitterNode
	assert_not_null(loaded_emitter, "重载后发射器节点应存在")
	assert_eq(loaded_emitter.output_direction, Vector2i(0, -1), "发射器方向应保留")
	assert_eq(loaded_emitter.element_type_id, "water", "发射器元素类型应保留")


func test_no_building_type_replaced_after_save() -> void:
	# 模拟连续多次自动保存，验证没有建筑类型被替换
	_bm.place_building(Vector2i(1, 1), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(2, 2), GameConfig.brick_type_id)
	_bm.place_building(Vector2i(3, 3), GameConfig.emitter_type_id)
	_bm.place_building(Vector2i(4, 4), GameConfig.collector_type_id)

	var expected_types := {
		Vector2i(1, 1): GameConfig.pipe_type_id,
		Vector2i(2, 2): GameConfig.brick_type_id,
		Vector2i(3, 3): GameConfig.emitter_type_id,
		Vector2i(4, 4): GameConfig.collector_type_id,
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
	_bm.place_building(Vector2i(2, 3), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(4, 5), GameConfig.brick_type_id)
	_bm.place_building(Vector2i(6, 7), GameConfig.emitter_type_id)

	_sm.save_buildings()

	# 重载
	_bm.clear_all_buildings()
	assert_false(_bm.has_building(Vector2i(2, 3)), "清除后建筑应不存在")
	_sm.load_buildings()

	# 验证所有非核心建筑类型正确
	assert_true(_bm.has_building(Vector2i(2, 3)), "加载后管道应存在")
	assert_true(_bm.has_building(Vector2i(4, 5)), "加载后砖块应存在")
	assert_true(_bm.has_building(Vector2i(6, 7)), "加载后发射器应存在")
	assert_eq(_bm.get_building_type(Vector2i(2, 3)), GameConfig.pipe_type_id, "管道类型应正确")
	assert_eq(_bm.get_building_type(Vector2i(4, 5)), GameConfig.brick_type_id, "砖块类型应正确")
	assert_eq(_bm.get_building_type(Vector2i(6, 7)), GameConfig.emitter_type_id, "发射器类型应正确")

	# 不应对核心产生影响
	assert_true(_bm.has_building(Vector2i(-1, -1)), "核心 (-1,-1) 应存在")
	assert_true(_bm.has_building(Vector2i(0, 0)), "核心 (0,0) 应存在")


func test_save_does_not_mutate_node_state() -> void:
	# 验证 save 操作不会改变节点的 visible/position 等状态
	_bm.place_building(Vector2i(5, 5), GameConfig.pipe_type_id)
	var pipe_node: PipeNode = _bm.get_building_node(Vector2i(5, 5)) as PipeNode
	assert_not_null(pipe_node, "管道节点应存在")

	var original_pos: Vector2 = pipe_node.global_position
	var original_visible: bool = pipe_node.visible

	# 执行多次保存
	for _i in range(3):
		_sm.save_buildings()

	assert_eq(pipe_node.global_position, original_pos, "保存不应改变建筑位置")
	assert_eq(pipe_node.visible, original_visible, "保存不应改变建筑可见性")


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
