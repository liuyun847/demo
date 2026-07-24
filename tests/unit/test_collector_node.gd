extends GutTest

const _CollectorScript = preload("res://scripts/building/collector_node.gd")

var _element_grid: ElementGrid = null
var _collector: Node = null

func before_each() -> void:
	_element_grid = autoqfree(ElementGrid.new())
	# 注入未 add_child 的 BuildingManager 实例，使 is_building_at 返回 false（见 test_element_grid.gd 注释）
	_element_grid.building_manager_ref = autoqfree(BuildingManager.new())
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
	_element_grid.set_element(Vector2i(0, 1), "water", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_gt(result, 0.0, "有元素时应收集到源质")
	assert_eq(result, 1.0, "每个元素单位价值 1.0")
	assert_false(_element_grid.has_element(Vector2i(0, 1)), "收集后元素应被移除")

func test_collector_collects_multiple_elements() -> void:
	_element_grid.set_element(Vector2i(1, 0), "water", 0)
	_element_grid.set_element(Vector2i(0, 1), "water", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 2.0, "两个元素 total 应为 2.0")

func test_collector_ignores_own_position() -> void:
	_element_grid.set_element(Vector2i(0, 0), "water", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 0.0, "收集器自身位置不应被收集")

func test_collector_name() -> void:
	assert_eq(_collector.get_building_name(), "收集器", "名称应为收集器")


# ========== 筛选元素类型测试 ==========

func test_collector_default_filter_empty() -> void:
	assert_eq(_collector.filter_element_type, "", "默认筛选应为空（收全部）")


func test_collector_set_filter() -> void:
	_collector.set_filter("water")
	assert_eq(_collector.filter_element_type, "water", "set_filter 应更新筛选类型")


func test_collector_empty_filter_collects_all_types() -> void:
	# 空筛选 = 收全部：water 和 fire 都应被收集
	_element_grid.set_element(Vector2i(1, 0), "water", 0)
	_element_grid.set_element(Vector2i(0, 1), "fire", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 2.0, "空筛选时应收集全部 2 个元素")
	assert_false(_element_grid.has_element(Vector2i(1, 0)), "water 应被收集")
	assert_false(_element_grid.has_element(Vector2i(0, 1)), "fire 应被收集")


func test_collector_specific_filter_only_collects_matching() -> void:
	# 设置筛选为 water，仅收集 water，fire 不被收集
	_collector.set_filter("water")
	_element_grid.set_element(Vector2i(1, 0), "water", 0)
	_element_grid.set_element(Vector2i(0, 1), "fire", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 1.0, "筛选 water 时仅应收集 1 个 water 元素")
	assert_false(_element_grid.has_element(Vector2i(1, 0)), "water 应被收集")
	assert_true(_element_grid.has_element(Vector2i(0, 1)), "fire 应保留（不匹配筛选）")


func test_collector_filter_no_matching_element() -> void:
	# 筛选 water，但只有 fire 元素 → 收集 0 个
	_collector.set_filter("water")
	_element_grid.set_element(Vector2i(0, 1), "fire", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 0.0, "无匹配元素时应返回 0")
	assert_true(_element_grid.has_element(Vector2i(0, 1)), "fire 应保留（不匹配筛选）")


func test_collector_steam_collect_value() -> void:
	# 蒸汽的 collect_value = 3.0，每个蒸汽格子应贡献 3.0 源质
	_element_grid.set_element(Vector2i(0, 1), "steam", 0)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 3.0, "蒸汽每个单位价值 3.0")
	assert_false(_element_grid.has_element(Vector2i(0, 1)), "收集后蒸汽应被移除")


func test_collector_skips_product_elements() -> void:
	# 反应产物在存续期内不应被收集（至少可见 1 tick）
	_element_grid.set_element(Vector2i(0, 1), "steam", 0)
	_element_grid.mark_as_product(Vector2i(0, 1), 3)
	var result: float = _collector.try_collect(_element_grid)
	assert_eq(result, 0.0, "有产物标记的元素不应被收集")
	assert_true(_element_grid.has_element(Vector2i(0, 1)), "产物应保留在格子上")
