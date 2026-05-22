extends GutTest

var _grid: ElementGrid = null
var _reaction: ElementReaction = null

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	_reaction = autoqfree(ElementReaction.new())

func after_each() -> void:
	_grid = null
	_reaction = null

func _create_element(element_type_id: String) -> ElementData:
	var element := ElementData.new()
	element.element_type = ElementRegistry.get_element_type(element_type_id)
	return element

func test_fire_earth_produces_lava() -> void:
	var earth := _create_element("earth")
	var fire := _create_element("fire")
	_grid.set_element(Vector2i(0, 0), earth)
	_grid.set_element(Vector2i(1, 0), fire)

	_reaction.process_all(_grid, ElementRegistry)

	assert_true(_grid.has_element(Vector2i(0, 0)) or _grid.has_element(Vector2i(1, 0)), "反应后至少应有一个格子有元素")
	var lava_found: bool = false
	for pos: Vector2i in _grid.get_all_element_positions():
		var el: ElementData = _grid.get_element(pos)
		if el.element_type.element_id == "lava":
			lava_found = true
			assert_eq(el.complexity, 2, "火+土→岩浆 复杂度应为 max(1,1)+1 = 2")
	assert_true(lava_found, "反应应生成岩浆")

func test_water_lava_produces_rock() -> void:
	var water := _create_element("water")
	var lava := _create_element("lava")
	lava.complexity = 2
	_grid.set_element(Vector2i(0, 0), water)
	_grid.set_element(Vector2i(1, 0), lava)

	_reaction.process_all(_grid, ElementRegistry)

	assert_true(_grid.has_element(Vector2i(0, 0)) or _grid.has_element(Vector2i(1, 0)), "反应后至少应有一个格子有元素")
	var rock_found: bool = false
	for pos: Vector2i in _grid.get_all_element_positions():
		var el: ElementData = _grid.get_element(pos)
		if el.element_type.element_id == "rock":
			rock_found = true
			assert_eq(el.complexity, 3, "水+岩浆→岩石 复杂度应为 max(1,2)+1 = 3")
	assert_true(rock_found, "反应应生成岩石")

func test_no_reaction_for_unmatched_pair() -> void:
	var water := _create_element("water")
	var fire := _create_element("fire")
	_grid.set_element(Vector2i(0, 0), water)
	_grid.set_element(Vector2i(0, 1), fire)

	_reaction.process_all(_grid, ElementRegistry)

	assert_true(_grid.has_element(Vector2i(0, 0)), "水应仍在原位")
	assert_true(_grid.has_element(Vector2i(0, 1)), "火应仍在原位")
	assert_eq(_grid.get_all_element_positions().size(), 2, "元素数量应保持不变")

func test_reaction_product_complexity() -> void:
	var earth := _create_element("earth")
	var complex_fire := _create_element("fire")
	complex_fire.complexity = 3
	_grid.set_element(Vector2i(0, 0), earth)
	_grid.set_element(Vector2i(1, 0), complex_fire)

	_reaction.process_all(_grid, ElementRegistry)

	var lava_found: bool = false
	for pos: Vector2i in _grid.get_all_element_positions():
		var el: ElementData = _grid.get_element(pos)
		if el.element_type.element_id == "lava":
			lava_found = true
			assert_eq(el.complexity, 4, "复杂度3+复杂度1 应生成复杂度4")
	assert_true(lava_found, "反应应生成岩浆")
