extends GutTest

# 注意：BuildingTypeManager._type_table 是 static var，跨测试共享。
# 这里在 before_each 中调用 reset_for_test 隔离用例；
# after_all 重新注册默认表，避免污染后续测试套件。
const _PipeNodeScript = preload("res://scripts/building/pipe_node.gd")


func before_each() -> void:
	BuildingTypeManager.reset_for_test()


func after_all() -> void:
	# 恢复默认注册（不含 type_01 容器类型，其余 9 个槽位），
	# 与 inventory_bar._init_default_types 行为对齐，避免后续测试依赖执行顺序。
	BuildingTypeManager.reset_for_test()
	var entries: Array = [
		[GameConfig.PIPE_TYPE_ID,      BuildingTypeData.Category.PIPE],
		[GameConfig.EMITTER_TYPE_ID,   BuildingTypeData.Category.EMITTER],
		[GameConfig.BRICK_TYPE_ID,     BuildingTypeData.Category.BRICK],
		["type_05",                    BuildingTypeData.Category.GENERIC],
		["type_06",                    BuildingTypeData.Category.GENERIC],
		[GameConfig.COLLECTOR_TYPE_ID, BuildingTypeData.Category.COLLECTOR],
		["type_08",                    BuildingTypeData.Category.GENERIC],
		["type_09",                    BuildingTypeData.Category.GENERIC],
		["type_10",                    BuildingTypeData.Category.GENERIC],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		td.category = entry[1]
		BuildingTypeManager.register(td)


## 构造 BuildingTypeData：props 中可包含 has_capacity / category
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
	assert_false(BuildingTypeManager.is_emitter("unknown"), "未知类型 is_emitter 应为 false")
	assert_false(BuildingTypeManager.is_collector("unknown"), "未知类型 is_collector 应为 false")


func test_is_pipe_specific() -> void:
	BuildingTypeManager.register(_make_type("pipe_x", {"category": BuildingTypeData.Category.PIPE}))
	assert_true(BuildingTypeManager.is_pipe("pipe_x"))


func test_is_emitter_specific() -> void:
	BuildingTypeManager.register(_make_type("emit_x", {"category": BuildingTypeData.Category.EMITTER}))
	assert_true(BuildingTypeManager.is_emitter("emit_x"))
	assert_false(BuildingTypeManager.is_collector("emit_x"))


func test_is_collector_specific() -> void:
	BuildingTypeManager.register(_make_type("col_x", {"category": BuildingTypeData.Category.COLLECTOR}))
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
		_make_type("b", {"category": BuildingTypeData.Category.PIPE}),
		_make_type("c", {"category": BuildingTypeData.Category.EMITTER}),
	]
	BuildingTypeManager.register_all(arr)
	assert_true(BuildingTypeManager.has_capacity("a"))
	assert_true(BuildingTypeManager.is_pipe("b"))
	assert_true(BuildingTypeManager.is_emitter("c"))


func test_register_all_skips_non_typedata() -> void:
	# 非 BuildingTypeData 元素应被忽略，不抛错
	BuildingTypeManager.register_all([null, "string", 42, _make_type("ok", {"category": BuildingTypeData.Category.PIPE})])
	assert_true(BuildingTypeManager.is_pipe("ok"))


func test_reset_for_test_clears_table() -> void:
	BuildingTypeManager.register(_make_type("temp", {"has_capacity": true}))
	assert_true(BuildingTypeManager.has_capacity("temp"))
	BuildingTypeManager.reset_for_test()
	assert_false(BuildingTypeManager.has_capacity("temp"), "reset 后查询应返回 false")


func test_register_overwrite() -> void:
	BuildingTypeManager.register(_make_type("dup", {"has_capacity": true, "category": BuildingTypeData.Category.GENERIC}))
	BuildingTypeManager.register(_make_type("dup", {"has_capacity": false, "category": BuildingTypeData.Category.PIPE}))
	assert_false(BuildingTypeManager.has_capacity("dup"), "同 type_id 重复 register 应覆盖")
	assert_true(BuildingTypeManager.is_pipe("dup"))


func test_full_property_matrix_for_pipe() -> void:
	BuildingTypeManager.register(_make_type("full", {
		"category": BuildingTypeData.Category.PIPE,
	}))
	assert_true(BuildingTypeManager.is_pipe("full"))
	assert_false(BuildingTypeManager.has_capacity("full"))
	assert_false(BuildingTypeManager.is_emitter("full"))
	assert_false(BuildingTypeManager.is_collector("full"))


## category 枚举化后新增测试：BRICK 类别查询
func test_is_brick_via_category() -> void:
	BuildingTypeManager.register(_make_type("brick_x", {"category": BuildingTypeData.Category.BRICK}))
	# BRICK 类别对其他 is_* 查询都应返回 false
	assert_false(BuildingTypeManager.is_pipe("brick_x"))
	assert_false(BuildingTypeManager.is_emitter("brick_x"))
	assert_false(BuildingTypeManager.is_collector("brick_x"))


## category 枚举化后新增测试：get_category 未注册返回 GENERIC
func test_get_category_unknown_returns_generic() -> void:
	assert_eq(BuildingTypeManager.get_category("unknown"), BuildingTypeData.Category.GENERIC, "未注册类型应返回 GENERIC")


## category 枚举化后新增测试：get_building_color default 行为
func test_get_building_color_default() -> void:
	# default/空字符串应返回 GameConfig.BUILDING_DEFAULT_COLOR
	var color_default: Color = BuildingTypeManager.get_building_color("default")
	assert_eq(color_default, GameConfig.BUILDING_DEFAULT_COLOR, "default 应返回 building_default_color")
	var color_empty: Color = BuildingTypeManager.get_building_color("")
	assert_eq(color_empty, GameConfig.BUILDING_DEFAULT_COLOR, "空字符串应返回 building_default_color")


## category 枚举化后新增测试：get_building_color type_01..type_10 HSV 色环
func test_get_building_color_type_indices() -> void:
	# type_01..type_10 按 HSV 色环均匀分布
	for idx in range(1, 11):
		var type_id := "type_%02d" % idx
		var color: Color = BuildingTypeManager.get_building_color(type_id)
		var expected := Color.from_hsv(float(idx - 1) / 10.0, 0.7, 0.9)
		assert_eq(color, expected, "%s 应返回预期 HSV 色环颜色" % type_id)
	# type_11 超出范围应回退到默认色
	var color_oob: Color = BuildingTypeManager.get_building_color("type_11")
	assert_eq(color_oob, GameConfig.BUILDING_DEFAULT_COLOR, "type_11 超出范围应回退到默认色")
