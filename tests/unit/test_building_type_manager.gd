extends GutTest

# 注意：BuildingTypeManager._type_table 是 static var，跨测试共享。
# 这里在 before_each 中调用 reset_for_test 隔离用例；
# after_all 重新注册默认表，避免污染后续测试套件。
const _ContainerNode = preload("res://scripts/building/container_node.gd")
const _PipeNodeScript = preload("res://scripts/building/pipe_node.gd")


func before_each() -> void:
	BuildingTypeManager.reset_for_test()


func after_all() -> void:
	# 恢复完整默认注册（含 type_01..type_10 全部 10 个槽位），
	# 与 inventory_bar._init_default_types 行为对齐，避免后续测试依赖执行顺序。
	BuildingTypeManager.reset_for_test()
	var entries: Array = [
		[GameConfig.container_type_id, {"has_capacity": true, "is_buffer": true}],
		[GameConfig.pipe_type_id,      {"is_pipe": true}],
		[GameConfig.emitter_type_id,   {"is_emitter": true}],
		[GameConfig.brick_type_id,     {}],
		["type_05", {}],
		["type_06", {}],
		[GameConfig.collector_type_id, {"is_collector": true}],
		["type_08", {}],
		["type_09", {}],
		["type_10", {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		BuildingTypeManager.register(td)


func _make_type(type_id: String, props: Dictionary) -> BuildingTypeData:
	var td := BuildingTypeData.new()
	td.type_id = type_id
	for k: String in props.keys():
		td.set(k, props[k])
	return td


func test_register_basic_type_and_query() -> void:
	BuildingTypeManager.register(_make_type("type_x", {"has_capacity": true}))
	assert_true(BuildingTypeManager.has_capacity("type_x"), "已注册类型应返回 true")


func test_unknown_type_id_returns_false_for_all() -> void:
	assert_false(BuildingTypeManager.has_capacity("unknown"), "未知类型 has_capacity 应为 false")
	assert_false(BuildingTypeManager.is_pipe("unknown"), "未知类型 is_pipe 应为 false")
	assert_false(BuildingTypeManager.is_buffer("unknown"), "未知类型 is_buffer 应为 false")
	assert_false(BuildingTypeManager.is_pipe_or_buffer("unknown"), "未知类型 is_pipe_or_buffer 应为 false")
	assert_false(BuildingTypeManager.is_emitter("unknown"), "未知类型 is_emitter 应为 false")
	assert_false(BuildingTypeManager.is_collector("unknown"), "未知类型 is_collector 应为 false")


func test_is_pipe_specific() -> void:
	BuildingTypeManager.register(_make_type("pipe_x", {"is_pipe": true}))
	assert_true(BuildingTypeManager.is_pipe("pipe_x"))
	assert_false(BuildingTypeManager.is_buffer("pipe_x"))
	assert_true(BuildingTypeManager.is_pipe_or_buffer("pipe_x"), "is_pipe 实现应使 is_pipe_or_buffer 为 true")


func test_is_buffer_specific() -> void:
	BuildingTypeManager.register(_make_type("buf_x", {"is_buffer": true}))
	assert_false(BuildingTypeManager.is_pipe("buf_x"))
	assert_true(BuildingTypeManager.is_buffer("buf_x"))
	assert_true(BuildingTypeManager.is_pipe_or_buffer("buf_x"))


func test_is_emitter_specific() -> void:
	BuildingTypeManager.register(_make_type("emit_x", {"is_emitter": true}))
	assert_true(BuildingTypeManager.is_emitter("emit_x"))
	assert_false(BuildingTypeManager.is_collector("emit_x"))


func test_is_collector_specific() -> void:
	BuildingTypeManager.register(_make_type("col_x", {"is_collector": true}))
	assert_true(BuildingTypeManager.is_collector("col_x"))
	assert_false(BuildingTypeManager.is_emitter("col_x"))


func test_has_capacity_default_false() -> void:
	BuildingTypeManager.register(_make_type("plain_x", {}))
	assert_false(BuildingTypeManager.has_capacity("plain_x"), "默认未设置 has_capacity 应为 false")


func test_register_with_empty_type_id_ignored() -> void:
	var td := BuildingTypeData.new()
	td.type_id = ""
	td.has_capacity = true
	BuildingTypeManager.register(td)
	assert_false(BuildingTypeManager.has_capacity(""), "空 type_id 注册应被忽略")


func test_register_with_null_ignored() -> void:
	BuildingTypeManager.register(null)
	# 不抛错即通过
	assert_true(true, "register(null) 应安全无副作用")


func test_register_all_batch() -> void:
	var arr: Array = [
		_make_type("a", {"has_capacity": true}),
		_make_type("b", {"is_pipe": true}),
		_make_type("c", {"is_emitter": true}),
	]
	BuildingTypeManager.register_all(arr)
	assert_true(BuildingTypeManager.has_capacity("a"))
	assert_true(BuildingTypeManager.is_pipe("b"))
	assert_true(BuildingTypeManager.is_emitter("c"))


func test_register_all_skips_non_typedata() -> void:
	# 非 BuildingTypeData 元素应被忽略，不抛错
	BuildingTypeManager.register_all([null, "string", 42, _make_type("ok", {"is_pipe": true})])
	assert_true(BuildingTypeManager.is_pipe("ok"))


func test_reset_for_test_clears_table() -> void:
	BuildingTypeManager.register(_make_type("temp", {"has_capacity": true}))
	assert_true(BuildingTypeManager.has_capacity("temp"))
	BuildingTypeManager.reset_for_test()
	assert_false(BuildingTypeManager.has_capacity("temp"), "reset 后查询应返回 false")


func test_register_overwrite() -> void:
	BuildingTypeManager.register(_make_type("dup", {"has_capacity": true}))
	BuildingTypeManager.register(_make_type("dup", {"has_capacity": false, "is_pipe": true}))
	assert_false(BuildingTypeManager.has_capacity("dup"), "同 type_id 重复 register 应覆盖")
	assert_true(BuildingTypeManager.is_pipe("dup"))


func test_is_container_node_with_container() -> void:
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	assert_true(BuildingTypeManager.is_container_node(node))


func test_is_container_node_with_pipe() -> void:
	var node: PipeNode = autoqfree(_PipeNodeScript.new())
	assert_false(BuildingTypeManager.is_container_node(node))


func test_is_container_node_with_node2d() -> void:
	var node: Node2D = autoqfree(Node2D.new())
	assert_false(BuildingTypeManager.is_container_node(node))


func test_is_container_node_with_null() -> void:
	assert_false(BuildingTypeManager.is_container_node(null))


func test_full_property_matrix_for_container() -> void:
	BuildingTypeManager.register(_make_type("full", {
		"has_capacity": true,
		"is_buffer": true,
	}))
	assert_true(BuildingTypeManager.has_capacity("full"))
	assert_true(BuildingTypeManager.is_buffer("full"))
	assert_true(BuildingTypeManager.is_pipe_or_buffer("full"))
	assert_false(BuildingTypeManager.is_pipe("full"))
	assert_false(BuildingTypeManager.is_emitter("full"))
	assert_false(BuildingTypeManager.is_collector("full"))
