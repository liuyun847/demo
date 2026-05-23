extends GutTest

var _element_grid: ElementGrid = null
var _emitter: EmitterNode = null
var _EmitterScript: GDScript = null

func before_all() -> void:
	_EmitterScript = load("res://scripts/building/emitter_node.gd") as GDScript

func before_each() -> void:
	_element_grid = autoqfree(ElementGrid.new()) as ElementGrid
	add_child_autoqfree(_element_grid)
	_emitter = autoqfree(_EmitterScript.new()) as EmitterNode
	_emitter.grid_position = Vector2i(0, 0)
	_emitter.element_type_id = "water"
	_emitter.output_direction = Vector2i(0, 1)
	_emitter.essence_cost_per_tick = 1.0
	add_child_autoqfree(_emitter)

func test_emitter_has_required_properties() -> void:
	assert_eq(_emitter.element_type_id, "water", "element_type_id 应为 water")
	assert_eq(_emitter.output_direction, Vector2i(0, 1), "output_direction 应向下")
	assert_eq(_emitter.essence_cost_per_tick, 1.0, "essence_cost_per_tick 应为 1.0")

func test_emitter_outputs_element_to_empty_cell() -> void:
	var result: bool = _emitter.try_output(_element_grid)
	assert_true(result, "向空格输出应成功")
	var element: ElementData = _element_grid.get_element(Vector2i(0, 1)) as ElementData
	assert_not_null(element, "目标格子应有元素")
	assert_eq(element.element_type.element_id, "water", "应为水元素")

func test_emitter_fails_when_target_occupied_by_element() -> void:
	_element_grid.set_element(Vector2i(0, 1), _create_element("fire"))
	var result: bool = _emitter.try_output(_element_grid)
	assert_false(result, "目标有元素时应返回 false")

func test_emitter_water_default_direction_down() -> void:
	var emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	emitter.element_type_id = "water"
	emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(emitter)
	assert_eq(emitter.get_default_direction(), Vector2i(0, 1), "水默认方向应向下")

func test_emitter_fire_default_direction_up() -> void:
	var emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	emitter.element_type_id = "fire"
	emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(emitter)
	assert_eq(emitter.get_default_direction(), Vector2i(0, -1), "火默认方向应向上")

func test_emitter_earth_default_direction_down() -> void:
	var emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	emitter.element_type_id = "earth"
	emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(emitter)
	assert_eq(emitter.get_default_direction(), Vector2i(0, 1), "土默认方向应向下")

func test_emitter_creates_element_with_complexity_1() -> void:
	_emitter.try_output(_element_grid)
	var element: ElementData = _element_grid.get_element(Vector2i(0, 1)) as ElementData
	assert_eq(element.complexity, 1, "发射器输出的元素复杂度应为 1")

func test_emitter_different_element_type() -> void:
	_emitter.element_type_id = "fire"
	var result: bool = _emitter.try_output(_element_grid)
	assert_true(result, "火喷口应能输出")
	var element: ElementData = _element_grid.get_element(Vector2i(0, 1)) as ElementData
	assert_eq(element.element_type.element_id, "fire", "应为火元素")

func test_emitter_get_building_name() -> void:
	_emitter.element_type_id = "water"
	assert_eq(_emitter.get_building_name(), "水喷口", "水喷口名称应正确")
	_emitter.element_type_id = "fire"
	assert_eq(_emitter.get_building_name(), "火喷口", "火喷口名称应正确")
	_emitter.element_type_id = "earth"
	assert_eq(_emitter.get_building_name(), "土喷口", "土喷口名称应正确")

func _create_element(type_id: String) -> ElementData:
	var element_type: ElementTypeData = ElementRegistry.get_element_type(type_id)
	var element: ElementData = ElementData.new()
	element.element_type = element_type
	element.complexity = 1
	return element
