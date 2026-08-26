extends GutTest

func test_num_item() -> void:
	var it := Item.num(5)
	assert_true(it.is_num(), "应为数字物品")
	assert_false(it.is_op(), "不应是操作物品")
	assert_eq(it.value, 5)

func test_op_item() -> void:
	var it := Item.op(OpRegistry.OP_ADD1)
	assert_true(it.is_op(), "应为操作物品")
	assert_false(it.is_num(), "不应是数字物品")
	assert_eq(it.value, OpRegistry.OP_ADD1)

func test_clone_independent() -> void:
	var it := Item.num(7)
	var copy := it.clone()
	copy.value = 8
	assert_eq(it.value, 7, "克隆修改不应影响原物品")

func test_equals() -> void:
	assert_true(Item.num(3).equals(Item.num(3)), "相同数字应相等")
	assert_false(Item.num(3).equals(Item.num(4)), "不同数字应不等")
	assert_false(Item.num(3).equals(Item.op(3)), "类型不同应不等")
	assert_false(Item.num(3).equals(null), "与 null 比较应为 false")

func test_display_text_num() -> void:
	assert_eq(Item.num(42).to_display_text(), "42")

func test_display_text_op() -> void:
	assert_eq(Item.op(OpRegistry.OP_ADD1).to_display_text(), "@+1")

func test_display_text_unknown_op() -> void:
	assert_eq(Item.op(999999).to_display_text(), "@?", "未注册操作应显示 ?")