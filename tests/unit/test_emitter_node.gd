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
	_emitter.essence_cost_per_tick = 1.0
	add_child_autoqfree(_emitter)

func test_emitter_default_water() -> void:
	assert_eq(_emitter.element_type_id, "water", "默认 element_type_id 应为 water")
	assert_true(_emitter.has_type_selected(), "has_type_selected 应返回 true")

func test_is_blocked_default_false() -> void:
	assert_false(_emitter.is_blocked(), "新喷口默认不应阻塞")

func test_emitter_has_required_properties() -> void:
	assert_eq(_emitter.element_type_id, "water", "默认应为 water")
	assert_eq(_emitter.essence_cost_per_tick, 1.0, "essence_cost_per_tick 应为 1.0")

func test_emitter_outputs_element_to_empty_cell() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	var result: bool = _emitter.try_output(_element_grid)
	assert_true(result, "向空格输出应成功")
	var element: ElementData = _element_grid.get_element(Vector2i(0, 1)) as ElementData
	assert_not_null(element, "目标格子应有元素")
	assert_eq(element.element_type.element_id, "water", "应为水元素")

func test_emitter_fails_when_target_occupied_by_element() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	_element_grid.set_element(Vector2i(0, 1), _create_element("water"))
	var result: bool = _emitter.try_output(_element_grid)
	assert_false(result, "目标有元素时应返回 false")

func test_emitter_default_direction_down() -> void:
	var emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(emitter)
	assert_eq(emitter.get_default_direction(), Vector2i(0, 1), "默认方向应向下")

func test_emitter_creates_element_with_complexity_1() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	_emitter.try_output(_element_grid)
	var element: ElementData = _element_grid.get_element(Vector2i(0, 1)) as ElementData
	assert_eq(element.complexity, 1, "发射器输出的元素复杂度应为 1")

func test_emitter_get_building_name() -> void:
	assert_eq(_emitter.get_building_name(), "喷口(水)", "喷口名称应为喷口(水)")

func test_set_output_direction() -> void:
	assert_eq(_emitter.output_direction, Vector2i(0, 1), "默认方向向下")
	_emitter.set_output_direction(Vector2i(0, -1))
	assert_eq(_emitter.output_direction, Vector2i(0, -1), "set_output_direction 应更新方向为上")

func test_emitter_blocked_cooldown() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	_element_grid.set_element(Vector2i(0, 1), _create_element("water"))

	var result1: bool = _emitter.try_output(_element_grid)
	assert_false(result1, "出口被堵时应返回 false 并进入冷却")
	assert_true(_emitter.is_blocked(), "被堵后 is_blocked 应返回 true")

	var result2: bool = _emitter.try_output(_element_grid)
	assert_false(result2, "冷却期间应返回 false（不检查目标）")
	assert_true(_emitter.is_blocked(), "冷却期间 is_blocked 仍为 true")

	_element_grid.remove_element(Vector2i(0, 1))
	for _i in range(GameConfig.emitter_blocked_cooldown - 1):
		_emitter.try_output(_element_grid)

	assert_false(_emitter.is_blocked(), "冷却结束后 is_blocked 应为 false")

	var result3: bool = _emitter.try_output(_element_grid)
	assert_true(result3, "冷却结束后出口通畅应恢复输出")

func _create_element(type_id: String) -> ElementData:
	var element_type: ElementTypeData = ElementRegistry.get_element_type(type_id)
	var element: ElementData = ElementData.new()
	element.element_type = element_type
	element.complexity = 1
	return element