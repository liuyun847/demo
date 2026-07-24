extends GutTest

const _O: Vector2i = Vector2i(5, 5)

## Mock 源质服务，用于验证依赖注入的测试隔离
class MockEssenceService:
	var essence: float = 0.0
	var add_calls: Array[float] = []
	func add(amount: float) -> void:
		add_calls.append(amount)
		essence += amount
	func subtract(amount: float) -> float:
		essence -= amount
		return amount
	func has(amount: float) -> bool:
		return essence >= amount

## Mock ElementGrid，可在产物放置阶段令 set_element 返回 false，
## 用于验证 ReactionProcessor 的防御性回滚分支（push_error 且不标记存续）。
class _FailProductGrid extends ElementGrid:
	var fail_set: bool = false
	func set_element(pos: Vector2i, element_id: String, source_y_val: int) -> bool:
		if fail_set:
			return false
		return super.set_element(pos, element_id, source_y_val)

var _grid: ElementGrid = null
var _registry: ReactionRegistry = null
var _processor: ReactionProcessor = null
var _saved_essence: float = 0.0
var _saved_element_types: Dictionary = {}

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	# 注入未 add_child 的 BuildingManager 实例，使 is_building_at 返回 false（见 test_element_grid.gd 注释）
	_grid.building_manager_ref = autoqfree(BuildingManager.new())
	_registry = ReactionRegistry.new()
	_registry.register("water", "fire", "steam", 0.0)
	# 生产环境使用 EssencePool 单例，Mock 隔离测试见 test_byproduct_uses_injected_service
	_processor = ReactionProcessor.new(_registry, _grid, EssencePool)
	# 保存并重置 EssencePool 状态
	_saved_essence = EssencePool.essence
	EssencePool.set_value(0.0)
	# 保存 ElementRegistry 状态（部分测试会注册自定义元素类型）
	_saved_element_types = ElementRegistry.get_all_element_types().duplicate()

func after_each() -> void:
	EssencePool.set_value(_saved_essence)
	# 恢复 ElementRegistry 状态（移除测试中注册的非标准元素）
	var current_types := ElementRegistry.get_all_element_types()
	for key: String in current_types:
		if not _saved_element_types.has(key):
			current_types.erase(key)

func test_water_fire_produces_steam() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.set_element(pos_b, "fire", pos_b.y)

	_processor.process_all()

	# reactant 已被消耗，产物 steam 放置在密度大的位置
	# 总元素数应为 1（两个 reactant 消耗，一个产物生成）
	assert_eq(_grid.get_all_element_positions().size(), 1, "反应后应只剩 1 个产物")
	# 产物应为 steam
	var product_pos: Vector2i = _grid.get_all_element_positions()[0]
	assert_eq(_grid.get_element_id(product_pos), "steam", "产物应为 steam")

func test_product_position_uses_density() -> void:
	# water density=1.0 > fire density=0.3，产物应在 water 位置
	var pos_water := _O + Vector2i(0, 0)
	var pos_fire := _O + Vector2i(1, 0)
	_grid.set_element(pos_water, "water", pos_water.y)
	_grid.set_element(pos_fire, "fire", pos_fire.y)

	_processor.process_all()

	assert_true(_grid.has_element(pos_water), "产物应在密度大的 water 位置")
	assert_eq(_grid.get_element_id(pos_water), "steam", "产物应为 steam")
	assert_false(_grid.has_element(pos_fire), "密度小的 fire 位置应为空")

func test_reacted_cell_no_double_reaction() -> void:
	# water(5,5) fire(6,5) water(7,5)
	# water+fire 反应后，第二个 water 不应与 steam 再次反应（同帧内）
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	var pos_c := _O + Vector2i(2, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.set_element(pos_b, "fire", pos_b.y)
	_grid.set_element(pos_c, "water", pos_c.y)

	_processor.process_all()

	# pos_c 的 water 应仍然存在（每帧最多参与一次反应）
	assert_true(_grid.has_element(pos_c), "未参与反应的 water 应保留")
	assert_eq(_grid.get_element_id(pos_c), "water", "pos_c 应仍为 water")

func test_byproduct_essence_added() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.set_element(pos_b, "fire", pos_b.y)

	_processor.process_all()

	# byproduct_essence = 0.0（副产物源质由收集器按 collect_value 产出）
	assert_eq(EssencePool.essence, 0.0, "反应不产生副产物源质")

func test_non_reactive_element_no_reaction() -> void:
	# 注册一个非反应元素类型
	var inert := ElementTypeData.new()
	inert.element_id = "inert"
	inert.display_name = "惰性"
	inert.color = Color.GRAY
	inert.state = ElementTypeData.State.SOLID
	inert.density = 5.0
	inert.reactive = false
	ElementRegistry.register_element_type(inert)

	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.set_element(pos_b, "inert", pos_b.y)

	_processor.process_all()

	# 两个元素都应保留（inert 非反应性）
	assert_true(_grid.has_element(pos_a), "water 应保留（inert 非反应性）")
	assert_true(_grid.has_element(pos_b), "inert 应保留")
	assert_eq(_grid.get_element_id(pos_a), "water", "pos_a 应仍为 water")

func test_product_survival_marker() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.set_element(pos_b, "fire", pos_b.y)

	_processor.process_all()

	# 产物应有存续标记
	var product_pos: Vector2i = pos_a if _grid.has_element(pos_a) else pos_b
	assert_true(_grid.is_product(product_pos), "反应产物应有存续标记")

func test_byproduct_uses_injected_service() -> void:
	# 使用 Mock 验证依赖注入：反应副产物源质应写入注入的服务而非全局 EssencePool
	var mock := MockEssenceService.new()
	var processor := ReactionProcessor.new(_registry, _grid, mock)

	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.set_element(pos_b, "fire", pos_b.y)

	processor.process_all()

	assert_eq(mock.add_calls.size(), 0, "byproduct=0.0 时 Mock 的 add 不应被调用")
	assert_eq(mock.essence, 0.0, "Mock 服务源质不应变化")
	assert_eq(EssencePool.essence, 0.0, "全局 EssencePool 不应被修改")

## 测试2: 产物放置失败时 push_error 且产物不标记存续
## ReactionProcessor.process_all 在 set_element 失败时应 push_error、跳过 mark_as_product
## 且不产生副产物源质。使用 _FailProductGrid 模拟产物放置失败。
func test_product_place_failure_no_mark() -> void:
	var grid: _FailProductGrid = autoqfree(_FailProductGrid.new())
	# 注入未 add_child 的 BuildingManager，使 is_building_at 返回 false（参考 test_element_grid.gd）
	grid.building_manager_ref = autoqfree(BuildingManager.new())
	var processor := ReactionProcessor.new(_registry, grid, EssencePool)

	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	# 放置 reactant（fail_set=false，成功）
	grid.set_element(pos_a, "water", pos_a.y)
	grid.set_element(pos_b, "fire", pos_b.y)

	# 令产物放置阶段 set_element 失败
	grid.fail_set = true
	EssencePool.set_value(0.0)

	processor.process_all()

	# 声明该 push_error 为预期，避免 GUT 将其计为失败，同时断言错误已触发
	assert_push_error("产物放置失败", "产物放置失败时应 push_error")
	# water density(1.0) > fire density(0.3)，产物位置 = pos_a
	assert_false(grid.is_product(pos_a), "产物放置失败时不应标记存续")
	assert_false(grid.has_element(pos_a), "产物不应被放置")
	assert_false(grid.has_element(pos_b), "fire reactant 已被消耗")
	assert_eq(EssencePool.essence, 0.0, "产物失败时不应产生副产物源质")
