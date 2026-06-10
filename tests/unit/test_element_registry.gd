extends GutTest

var _registry: Node = null

func before_each() -> void:
	_registry = autoqfree(Node.new())
	_registry.set_script(load("res://scripts/elements/element_registry.gd"))
	add_child_autoqfree(_registry)

func after_each() -> void:
	_registry = null

func test_default_elements_registered() -> void:
	assert_not_null(_registry.get_element_type("water"), "water 元素应已注册")
	assert_null(_registry.get_element_type("fire"), "fire 元素不应存在于默认注册中")
	assert_null(_registry.get_element_type("earth"), "earth 元素不应存在于默认注册中")
	assert_null(_registry.get_element_type("lava"), "lava 元素不应存在于默认注册中")
	assert_null(_registry.get_element_type("rock"), "rock 元素不应存在于默认注册中")

func test_get_element_type_by_id() -> void:
	var water_type: ElementTypeData = _registry.get_element_type("water")
	assert_not_null(water_type, "water 元素类型应存在")
	assert_eq(water_type.display_name, "水", "水的显示名应正确")

func test_get_nonexistent_element_returns_null() -> void:
	var result: ElementTypeData = _registry.get_element_type("nonexistent")
	assert_null(result, "不存在的元素 ID 应返回 null")

func test_register_new_element() -> void:
	var fire := ElementTypeData.new()
	fire.element_id = "fire"
	fire.display_name = "火"
	_registry.register_element_type(fire)

	var retrieved: ElementTypeData = _registry.get_element_type("fire")
	assert_not_null(retrieved, "新注册的元素应可查询")
	assert_eq(retrieved.display_name, "火", "新注册元素的显示名应正确")

func test_register_overwrites_existing() -> void:
	var modified_water := ElementTypeData.new()
	modified_water.element_id = "water"
	modified_water.display_name = "H2O"
	_registry.register_element_type(modified_water)

	var retrieved: ElementTypeData = _registry.get_element_type("water")
	assert_not_null(retrieved, "覆盖注册后元素仍可查询")
	assert_eq(retrieved.display_name, "H2O", "覆盖注册后显示名应更新")

func test_register_multiple_elements() -> void:
	var elements: Array[String] = ["fire", "earth", "air"]
	for elem_id: String in elements:
		var type_data := ElementTypeData.new()
		type_data.element_id = elem_id
		type_data.display_name = elem_id
		_registry.register_element_type(type_data)

	for elem_id: String in elements:
		var retrieved: ElementTypeData = _registry.get_element_type(elem_id)
		assert_not_null(retrieved, "多元素注册后 '%s' 应可查询" % elem_id)
		assert_eq(retrieved.display_name, elem_id, "元素 '%s' 的显示名应正确" % elem_id)