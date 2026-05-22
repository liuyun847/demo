extends GutTest

func test_default_values() -> void:
	var type_data := ElementTypeData.new()
	assert_eq(type_data.gravity, 1.0, "默认 gravity 应为 1.0")
	assert_eq(type_data.diffusion_rate, 0.0, "默认 diffusion_rate 应为 0.0")
	assert_eq(type_data.lateral_priority, 0.5, "默认 lateral_priority 应为 0.5")
	assert_eq(type_data.base_value, 1.0, "默认 base_value 应为 1.0")

func test_custom_values() -> void:
	var type_data := ElementTypeData.new()
	type_data.element_id = "test_element"
	type_data.display_name = "测试元素"
	type_data.gravity = -0.5
	type_data.diffusion_rate = 0.8
	type_data.lateral_priority = 0.3
	type_data.base_value = 2.5

	assert_eq(type_data.element_id, "test_element", "element_id 应正确赋值")
	assert_eq(type_data.display_name, "测试元素", "display_name 应正确赋值")
	assert_eq(type_data.gravity, -0.5, "gravity 应正确赋值")
	assert_eq(type_data.diffusion_rate, 0.8, "diffusion_rate 应正确赋值")
	assert_eq(type_data.lateral_priority, 0.3, "lateral_priority 应正确赋值")
	assert_eq(type_data.base_value, 2.5, "base_value 应正确赋值")

func test_color_assignment() -> void:
	var type_data := ElementTypeData.new()
	type_data.color = Color("#4488ff")
	assert_eq(type_data.color, Color("#4488ff"), "颜色应正确赋值")
