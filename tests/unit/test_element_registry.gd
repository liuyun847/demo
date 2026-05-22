extends GutTest

func test_default_elements_registered() -> void:
	assert_not_null(ElementRegistry.get_element_type("water"), "water 元素应已注册")
	assert_not_null(ElementRegistry.get_element_type("fire"), "fire 元素应已注册")
	assert_not_null(ElementRegistry.get_element_type("earth"), "earth 元素应已注册")
	assert_not_null(ElementRegistry.get_element_type("lava"), "lava 元素应已注册")
	assert_not_null(ElementRegistry.get_element_type("rock"), "rock 元素应已注册")

func test_get_element_type_by_id() -> void:
	var water_type: ElementTypeData = ElementRegistry.get_element_type("water")
	assert_not_null(water_type, "water 元素类型应存在")
	assert_eq(water_type.display_name, "水", "水的显示名应正确")
	assert_eq(water_type.gravity, 0.5, "水的重力应正确")

	var fire_type: ElementTypeData = ElementRegistry.get_element_type("fire")
	assert_not_null(fire_type, "fire 元素类型应存在")
	assert_eq(fire_type.display_name, "火", "火的显示名应正确")
	assert_eq(fire_type.gravity, -0.8, "火的重力应正确")

func test_get_nonexistent_element_returns_null() -> void:
	var result: ElementTypeData = ElementRegistry.get_element_type("nonexistent")
	assert_null(result, "不存在的元素 ID 应返回 null")

func test_symmetric_reaction_lookup() -> void:
	var result_ab: String = ElementRegistry.get_reaction("fire", "earth")
	assert_eq(result_ab, "lava", "fire+earth 应生成 lava")

	var result_ba: String = ElementRegistry.get_reaction("earth", "fire")
	assert_eq(result_ba, "lava", "earth+fire 应生成 lava（对称查找）")

func test_second_reaction() -> void:
	var result: String = ElementRegistry.get_reaction("water", "lava")
	assert_eq(result, "rock", "water+lava 应生成 rock")

func test_reaction_not_found_returns_empty() -> void:
	var result: String = ElementRegistry.get_reaction("water", "fire")
	assert_eq(result, "", "无配方的组合应返回空字符串")

func test_complexity_calculation() -> void:
	var result: int = ElementRegistry.calculate_complexity(1, 1)
	assert_eq(result, 2, "max(1,1)+1 = 2")

	result = ElementRegistry.calculate_complexity(2, 1)
	assert_eq(result, 3, "max(2,1)+1 = 3")

	result = ElementRegistry.calculate_complexity(3, 3)
	assert_eq(result, 4, "max(3,3)+1 = 4")

func test_value_calculation() -> void:
	var water_type: ElementTypeData = ElementRegistry.get_element_type("water")
	var rock_type: ElementTypeData = ElementRegistry.get_element_type("rock")

	var water_value: float = ElementRegistry.calculate_value(water_type, 1)
	assert_eq(water_value, 1.5, "水(base=1.0) 复杂度1 价值应为 1.5")

	var rock_value: float = ElementRegistry.calculate_value(rock_type, 3)
	assert_eq(rock_value, 9.0, "岩石(base=3.0) 复杂度3 价值应为 9.0")

func test_step_coefficient() -> void:
	assert_eq(ElementRegistry.get_step_coefficient(1), 1.5, "步数1 系数应为 1.5")
	assert_eq(ElementRegistry.get_step_coefficient(2), 2.0, "步数2 系数应为 2.0")
	assert_eq(ElementRegistry.get_step_coefficient(3), 3.0, "步数3 系数应为 3.0")
	assert_eq(ElementRegistry.get_step_coefficient(0), 1.0, "步数0 系数应为 1.0")
	assert_eq(ElementRegistry.get_step_coefficient(4), 1.0, "步数4 系数应为 1.0")
