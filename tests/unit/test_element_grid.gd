extends GutTest

var _grid: ElementGrid = null

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	# 注入未 add_child 的 BuildingManager 实例：
	# 其 _ready() 不会触发，get_building_node 返回 null，使 is_building_at 返回 false，
	# 避免 ElementGrid 的 null 防护阻止 set_element（批次 5.4 修改的兼容）
	_grid.building_manager_ref = autoqfree(BuildingManager.new())

func after_each() -> void:
	_grid = null

func test_set_element_empty_position() -> void:
	var result: bool = _grid.set_element(Vector2i(0, 0), "water", 0)
	assert_true(result, "在空格子放置元素应成功")
	assert_true(_grid.has_element(Vector2i(0, 0)), "该格子应有元素")

func test_set_element_occupied_position() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	var result: bool = _grid.set_element(Vector2i(0, 0), "water", 0)
	assert_false(result, "在已有元素的格子放置元素应失败")

func test_set_element_stores_source_y() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 5)
	assert_eq(_grid.get_source_y(Vector2i(0, 0)), 5, "source_y 应正确存储")

func test_remove_element() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.remove_element(Vector2i(0, 0))
	assert_false(_grid.has_element(Vector2i(0, 0)), "移除后格子应为空")

func test_remove_nonexistent_element() -> void:
	_grid.remove_element(Vector2i(99, 99))
	assert_false(_grid.has_element(Vector2i(99, 99)), "不存在的位置，has_element 应返回 false")

func test_move_element() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 5)
	var result: bool = _grid.move_element(Vector2i(0, 0), Vector2i(1, 0))
	assert_true(result, "移动元素应成功")
	assert_false(_grid.has_element(Vector2i(0, 0)), "原位置应无元素")
	assert_true(_grid.has_element(Vector2i(1, 0)), "目标位置应有元素")
	assert_eq(_grid.get_source_y(Vector2i(1, 0)), 5, "目标位置应继承 source_y")

func test_move_element_to_occupied() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.set_element(Vector2i(1, 0), "water", 0)
	var result: bool = _grid.move_element(Vector2i(0, 0), Vector2i(1, 0))
	assert_false(result, "移动到有元素的位置应失败")

func test_is_position_available_empty() -> void:
	assert_true(_grid.is_position_available(Vector2i(5, 5)), "空格子应可用")

func test_is_position_available_with_element() -> void:
	_grid.set_element(Vector2i(3, 3), "water", 0)
	assert_false(_grid.is_position_available(Vector2i(3, 3)), "有元素的格子应不可用")

func test_get_all_element_positions() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.set_element(Vector2i(1, 1), "water", 0)

	var positions: Array[Vector2i] = _grid.get_all_element_positions()
	assert_eq(positions.size(), 2, "应有 2 个元素位置")

func test_clear_all() -> void:
	_grid.set_element(Vector2i(0, 0), "water", 0)
	_grid.set_element(Vector2i(1, 1), "water", 0)

	_grid.clear_all()
	assert_eq(_grid.get_all_element_positions().size(), 0, "清空后应无元素")

# 测试7: is_building_at null 防护测试
# 验证 building_manager_ref 为 null 时 is_building_at 返回 true 并 push_warning，阻止元素放置
func test_is_building_at_null_ref_returns_true_with_warning() -> void:
	# before_each 已注入 BuildingManager，此处置空以测试 null 防护
	_grid.building_manager_ref = null
	var result: bool = _grid.is_building_at(Vector2i(0, 0))
	assert_true(result, "building_manager_ref 为 null 时 is_building_at 应返回 true 阻止放置")
	assert_push_warning("building_manager_ref 未初始化", "应 push_warning 提示未初始化")

# 测试8: move_element 水源标记+产物标记迁移测试
# 验证 move_element 将 _source_positions 和 _product_timers 标记从 from 迁移到 to
func test_move_element_transfers_source_and_product_marks() -> void:
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(1, 0)
	_grid.set_element(from, "water", 5)
	_grid.mark_as_source(from)
	_grid.mark_as_product(from, 3)

	var result: bool = _grid.move_element(from, to)
	assert_true(result, "移动元素应成功")
	assert_true(_grid.is_source_pos(to), "迁移后 to 位置应保持水源标记")
	assert_true(_grid.is_product(to), "迁移后 to 位置应保持产物标记")
	assert_false(_grid.is_source_pos(from), "迁移后 from 位置不应保留水源标记")
	assert_false(_grid.is_product(from), "迁移后 from 位置不应保留产物标记")
