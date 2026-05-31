extends GutTest

func test_default_elements_registered() -> void:
	assert_not_null(ElementRegistry.get_element_type("water"), "water 元素应已注册")
	assert_null(ElementRegistry.get_element_type("fire"), "fire 元素应已移除")
	assert_null(ElementRegistry.get_element_type("earth"), "earth 元素应已移除")
	assert_null(ElementRegistry.get_element_type("lava"), "lava 元素应已移除")
	assert_null(ElementRegistry.get_element_type("rock"), "rock 元素应已移除")

func test_get_element_type_by_id() -> void:
	var water_type: ElementTypeData = ElementRegistry.get_element_type("water")
	assert_not_null(water_type, "water 元素类型应存在")
	assert_eq(water_type.display_name, "水", "水的显示名应正确")

func test_get_nonexistent_element_returns_null() -> void:
	var result: ElementTypeData = ElementRegistry.get_element_type("nonexistent")
	assert_null(result, "不存在的元素 ID 应返回 null")
