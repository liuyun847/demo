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

func test_emitter_has_required_properties() -> void:
	assert_eq(_emitter.element_type_id, "water", "默认应为 water")
	assert_eq(_emitter.essence_cost_per_tick, 1.0, "essence_cost_per_tick 应为 1.0")

func test_emitter_outputs_element_to_empty_cell() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	var result: bool = _emitter.try_output(_element_grid)
	assert_true(result, "向空格输出应成功")
	assert_true(_element_grid.has_fluid(Vector2i(0, 1)), "目标格子应有流体")

func test_emitter_outputs_uses_emitter_y_as_source_y() -> void:
	_emitter.grid_position = Vector2i(5, 3)
	_emitter.output_direction = Vector2i(0, 1)
	_emitter.try_output(_element_grid)
	assert_eq(_element_grid.get_source_y(Vector2i(5, 4)), 3, "source_y 应等于 emitter.y")

func test_emitter_fails_when_target_occupied_by_element() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	_element_grid.set_fluid(Vector2i(0, 1), 0)
	var result: bool = _emitter.try_output(_element_grid)
	assert_false(result, "目标有流体时应返回 false")

func test_emitter_outputs_again_when_target_freed() -> void:
	_emitter.output_direction = Vector2i(0, 1)
	_element_grid.set_fluid(Vector2i(0, 1), 0)
	assert_false(_emitter.try_output(_element_grid), "出口被堵时应返回 false")

	_element_grid.remove_fluid(Vector2i(0, 1))
	var result: bool = _emitter.try_output(_element_grid)
	assert_true(result, "出口恢复通畅后应成功输出")
	assert_true(_element_grid.has_fluid(Vector2i(0, 1)), "目标格子应有新流体")

func test_emitter_default_direction_down() -> void:
	var emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(emitter)
	assert_eq(emitter.get_default_direction(), Vector2i(0, 1), "默认方向应向下")

func test_emitter_get_building_name() -> void:
	assert_eq(_emitter.get_building_name(), "喷口(水)", "喷口名称应为喷口(水)")

func test_set_output_direction() -> void:
	assert_eq(_emitter.output_direction, Vector2i(0, 1), "默认方向向下")
	_emitter.set_output_direction(Vector2i(0, -1))
	assert_eq(_emitter.output_direction, Vector2i(0, -1), "set_output_direction 应更新方向为上")
