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

func test_earth_does_not_move() -> void:
	var earth := _create_element("earth")
	_grid.set_element(Vector2i(0, 0), earth)

	_diffusion.diffuse_all(_grid, 10)

	assert_true(_grid.has_element(Vector2i(0, 0)), "土(diffusion_rate=0) 不应移动")
	assert_eq(_grid.get_all_element_positions().size(), 1, "元素数量应保持不变")

func test_rock_does_not_move() -> void:
	var rock := _create_element("rock")
	_grid.set_element(Vector2i(0, 0), rock)

	_diffusion.diffuse_all(_grid, 10)

	assert_true(_grid.has_element(Vector2i(0, 0)), "岩石(diffusion_rate=0) 不应移动")
	assert_eq(_grid.get_all_element_positions().size(), 1, "元素数量应保持不变")

func test_elements_preserved_after_diffusion() -> void:
	var water := _create_element("water")
	var fire := _create_element("fire")
	_grid.set_element(Vector2i(0, 0), water)
	_grid.set_element(Vector2i(5, 5), fire)

	_diffusion.diffuse_all(_grid, 3)

	var count: int = _grid.get_all_element_positions().size()
	assert_eq(count, 2, "扩散后元素总数应保持不变")

func test_total_count_preserved_multiple_steps() -> void:
	var elements: Array[ElementData] = []
	for i in range(5):
		var el := _create_element("water")
		_grid.set_element(Vector2i(i * 2, 0), el)
		elements.append(el)

	_diffusion.diffuse_all(_grid, 6)

	var count: int = _grid.get_all_element_positions().size()
	assert_eq(count, 5, "多次扩散后元素总数应保持不变")
