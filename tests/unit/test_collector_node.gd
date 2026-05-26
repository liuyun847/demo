extends GutTest

const _CollectorScript = preload("res://scripts/building/collector_node.gd")

var _element_grid: ElementGrid = null
var _collector: Node = null

func before_each() -> void:
	_element_grid = autoqfree(ElementGrid.new())
	add_child_autoqfree(_element_grid)
	_collector = autoqfree(_CollectorScript.new())
	_collector.grid_position = Vector2i(0, 0)
	_collector.collection_radius = 1
	add_child_autoqfree(_collector)

func test_collector_has_properties() -> void:
	assert_eq(_collector.collection_radius, 1, "默认收集半径应为 1")

func test_collector_collects_nothing_from_empty_area() -> void:
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 0.0, "空区域收集应为 0")

func test_collector_collects_element_and_returns_essence() -> void:
	_element_grid.set_element(Vector2i(0, 1), _create_element("water", 1))
	var result: float = _collector.try_collect(_element_grid)
	assert_gt(result, 0.0, "有水元素时应收集到源质")
	assert_eq(result, 1.0, "水(base=1.0) 价值应为 1.0")
	assert_null(_element_grid.get_element(Vector2i(0, 1)), "收集后元素应被移除")

func test_collector_collects_multiple_elements() -> void:
	_element_grid.set_element(Vector2i(1, 0), _create_element("water", 1))
	_element_grid.set_element(Vector2i(0, 1), _create_element("water", 1))
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 2.0, "两个水元素 total 应为 2.0")

func test_collector_ignores_own_position() -> void:
	_element_grid.set_element(Vector2i(0, 0), _create_element("water", 1))
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 0.0, "收集器自身位置不应被收集")

func test_collector_name() -> void:
	assert_eq(_collector.get_building_name(), "收集器", "名称应为收集器")

func _create_element(type_id: String, complexity: int) -> ElementData:
	var element_type: ElementTypeData = ElementRegistry.get_element_type(type_id)
	var element := ElementData.new()
	element.element_type = element_type
	element.complexity = complexity
	return element