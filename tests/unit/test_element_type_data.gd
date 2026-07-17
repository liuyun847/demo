extends GutTest

func test_default_values() -> void:
	var type_data := ElementTypeData.new()
	assert_eq(type_data.element_id, "", "默认 element_id 应为空")
	assert_eq(type_data.display_name, "", "默认 display_name 应为空")
	# state 枚举化后默认值为 LIQUID
	assert_eq(type_data.state, ElementTypeData.State.LIQUID, "默认 state 应为 LIQUID")

func test_custom_values() -> void:
	var type_data := ElementTypeData.new()
	type_data.element_id = "test_element"
	type_data.display_name = "测试元素"

	assert_eq(type_data.element_id, "test_element", "element_id 应正确赋值")
	assert_eq(type_data.display_name, "测试元素", "display_name 应正确赋值")

func test_color_assignment() -> void:
	var type_data := ElementTypeData.new()
	type_data.color = Color("#4488ff")
	assert_eq(type_data.color, Color("#4488ff"), "颜色应正确赋值")

## state 枚举化后新增测试：所有枚举值可正常赋值与读取
func test_state_enum_assignable() -> void:
	var type_data := ElementTypeData.new()
	var states: Array[ElementTypeData.State] = [
		ElementTypeData.State.LIQUID,
		ElementTypeData.State.GAS,
		ElementTypeData.State.SOLID,
	]
	for st: ElementTypeData.State in states:
		type_data.state = st
		assert_eq(type_data.state, st, "state 应能正确赋值与读取: %d" % st)
