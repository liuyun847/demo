extends GutTest

func test_default_values() -> void:
	var type_data := ElementTypeData.new()
	assert_eq(type_data.element_id, "", "默认 element_id 应为空")
	assert_eq(type_data.display_name, "", "默认 display_name 应为空")

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
