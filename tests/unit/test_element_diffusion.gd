extends GutTest

var _grid: ElementGrid = null
var _diffusion: ElementDiffusion = null

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	_diffusion = autoqfree(ElementDiffusion.new())

func after_each() -> void:
	_grid = null
	_diffusion = null

func _create_element(element_type_id: String) -> ElementData:
	var element := ElementData.new()
	element.element_type = ElementRegistry.get_element_type(element_type_id)
	return element

func test_water_spreads_down_and_lateral() -> void:
	var water := _create_element("water")
	_grid.set_element(Vector2i(0, 0), water)

	_diffusion.diffuse_all(_grid, 5)

	assert_true(_grid.has_element(Vector2i(0, 0)), "水源位置应保留")
	assert_true(_grid.has_element(Vector2i(0, 5)), "水应向下扩展到 Y=5")
	var count: int = _grid.get_all_element_positions().size()
	assert_gt(count, 6, "水有横向扩散，数量应大于纯向下扩展")

func test_water_blocked_spreads_around() -> void:
	var water := _create_element("water")
	_grid.set_element(Vector2i(0, 0), water)
	_grid.set_element(Vector2i(0, 1), _create_element("water"))

	_diffusion.diffuse_all(_grid, 5)

	assert_true(_grid.has_element(Vector2i(0, 0)), "水源位置应保留")
	assert_true(_grid.has_element(Vector2i(0, 1)), "障碍位置应保留")
	var all_positions: Array[Vector2i] = _grid.get_all_element_positions()
	assert_gt(all_positions.size(), 2, "水应绕过障碍向旁侧扩散")

func test_elements_grow_during_diffusion() -> void:
	var water := _create_element("water")
	_grid.set_element(Vector2i(0, 0), water)

	_diffusion.diffuse_all(_grid, 3)

	var count: int = _grid.get_all_element_positions().size()
	assert_gt(count, 1, "扩散后元素总数应增长")
	assert_true(_grid.has_element(Vector2i(0, 0)), "水源位置应保留")

func test_total_count_grows_multiple_steps() -> void:
	for i in range(5):
		var el := _create_element("water")
		_grid.set_element(Vector2i(i * 2, 0), el)

	_diffusion.diffuse_all(_grid, 3)

	var count: int = _grid.get_all_element_positions().size()
	assert_gt(count, 5, "多次扩散后元素总数应增长")