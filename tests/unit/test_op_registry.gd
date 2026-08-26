extends GutTest

func before_each() -> void:
	OpRegistry.reset()

func test_builtin_apply_add1() -> void:
	assert_eq(OpRegistry.apply(OpRegistry.OP_ADD1, 1), 2)
	assert_eq(OpRegistry.apply(OpRegistry.OP_ADD1, -1), 0)

func test_builtin_apply_sub1() -> void:
	assert_eq(OpRegistry.apply(OpRegistry.OP_SUB1, 1), 0)
	assert_eq(OpRegistry.apply(OpRegistry.OP_SUB1, -5), -6)

func test_builtin_apply_mul2() -> void:
	assert_eq(OpRegistry.apply(OpRegistry.OP_MUL2, 21), 42)

func test_builtin_apply_div2_truncates_toward_zero() -> void:
	assert_eq(OpRegistry.apply(OpRegistry.OP_DIV2, 7), 3)
	assert_eq(OpRegistry.apply(OpRegistry.OP_DIV2, -7), -3, "向零整除：-7/2 = -3")

func test_builtin_apply_neg() -> void:
	assert_eq(OpRegistry.apply(OpRegistry.OP_NEG, 5), -5)
	assert_eq(OpRegistry.apply(OpRegistry.OP_NEG, -5), 5)

func test_builtin_apply_is_zero() -> void:
	assert_eq(OpRegistry.apply(OpRegistry.OP_IS_ZERO, 0), 1)
	assert_eq(OpRegistry.apply(OpRegistry.OP_IS_ZERO, 3), 0)
	assert_eq(OpRegistry.apply(OpRegistry.OP_IS_ZERO, -1), 0)

func test_overflow_wraps() -> void:
	var max_int: int = 9223372036854775807
	assert_eq(OpRegistry.apply(OpRegistry.OP_ADD1, max_int), -9223372036854775808, "int64 溢出应回绕")

func test_compose_applies_first_then_second() -> void:
	# f(x) = 2 * (x + 1)
	var id := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	assert_true(OpRegistry.has(id), "合成操作应注册")
	assert_eq(OpRegistry.apply(id, 3), 8, "先 +1 再 ×2：(3+1)*2 = 8")
	assert_false(OpRegistry.is_builtin(id), "合成操作不是内置操作")

func test_compose_of_composite() -> void:
	# ((x+1)*2) 再 +1
	var inner := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	var outer := OpRegistry.compose(inner, OpRegistry.OP_ADD1)
	assert_eq(OpRegistry.apply(outer, 3), 9, "(3+1)*2+1 = 9")

func test_compose_ids_unique_and_increasing() -> void:
	var id_a := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_SUB1)
	var id_b := OpRegistry.compose(OpRegistry.OP_MUL2, OpRegistry.OP_NEG)
	assert_ne(id_a, id_b, "不同组合应产生不同 id")

func test_compose_idempotent_same_definition() -> void:
	# 同内容组合幂等：表内已有相同定义则复用同一 id（防 id 膨胀）
	var id_a := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	var id_b := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	assert_eq(id_a, id_b, "同内容组合应复用同一 id")

func test_definition_of_builtin() -> void:
	assert_eq(OpRegistry.definition_of(OpRegistry.OP_ADD1), "add1")
	assert_eq(OpRegistry.definition_of(OpRegistry.OP_IS_ZERO), "iszero")

func test_composite_definition_roundtrip_after_reset() -> void:
	# 跨会话持久化：compose 后取定义串；reset 模拟新会话（表清空），
	# ensure_from_definition 应重建出语义一致的新 id，且幂等
	var old_id := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	var def: String = OpRegistry.definition_of(old_id)
	assert_true(def.contains("compose"), "复合操作定义应表达合成信息")
	OpRegistry.reset()
	var new_id := OpRegistry.ensure_from_definition(def)
	assert_true(OpRegistry.has(new_id), "重建后应注册成功")
	assert_eq(OpRegistry.apply(new_id, 3), 8, "重建后语义应一致：先 +1 再 ×2")
	assert_eq(OpRegistry.ensure_from_definition(def), new_id, "同定义重复恢复应幂等同 id")

func test_nested_composite_definition_roundtrip() -> void:
	# 嵌套复合（((x+1)*2)+1）的定义串跨会话重建
	var inner := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	var old_id := OpRegistry.compose(inner, OpRegistry.OP_ADD1)
	var def: String = OpRegistry.definition_of(old_id)
	OpRegistry.reset()
	var new_id := OpRegistry.ensure_from_definition(def)
	assert_true(OpRegistry.has(new_id), "嵌套复合重建应成功")
	assert_eq(OpRegistry.apply(new_id, 3), 9, "嵌套复合重建后语义应一致")
	assert_eq(OpRegistry.op_name(new_id), "+1→×2→+1", "嵌套复合重建后显示名应一致")

func test_ensure_from_unknown_definition_returns_minus_one() -> void:
	assert_eq(OpRegistry.ensure_from_definition(""), -1)
	assert_eq(OpRegistry.ensure_from_definition("not_an_op"), -1)
	assert_eq(OpRegistry.ensure_from_definition("[\"compose\",\"add1\",\"no_such_op\"]"), -1)

func test_apply_unknown_op_returns_value() -> void:
	assert_eq(OpRegistry.apply(999999, 5), 5, "未注册操作应返回原值（防御）")

func test_names() -> void:
	assert_eq(OpRegistry.op_name(OpRegistry.OP_ADD1), "+1")
	var id := OpRegistry.compose(OpRegistry.OP_ADD1, OpRegistry.OP_MUL2)
	assert_eq(OpRegistry.op_name(id), "+1→×2", "合成名应表达先后顺序")

func test_builtin_ids_stable() -> void:
	var ids := OpRegistry.get_builtin_ids()
	assert_eq(ids.size(), 6, "内置操作共 6 个")