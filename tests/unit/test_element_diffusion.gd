extends GutTest

const _BM: GDScript = preload("res://scripts/building/building_manager.gd")
const _PRS: GDScript = preload("res://scripts/building/pipe_render_system.gd")

var _grid: ElementGrid = null
var _diffusion: ElementDiffusion = null
var _bm: BuildingManager = null

# 偏移量，避开 BuildingManager 核心占据的 (0,0)-(1,1) 区域
const _O: Vector2i = Vector2i(5, 5)


## Mock 源质服务，用于验证扩张时逐个检查源质可负担性
class _MockEssence:
	var essence: float = 0.0
	func add(amount: float) -> void:
		essence += amount
	func subtract(amount: float) -> float:
		essence -= amount
		return amount
	func has(amount: float) -> bool:
		return essence >= amount


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.PIPE_TYPE_ID):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.PIPE_TYPE_ID,      {"category": BuildingTypeData.Category.PIPE}],
		[GameConfig.SOURCE_TYPE_ID,    {"category": BuildingTypeData.Category.SOURCE}],
		[GameConfig.COLLECTOR_TYPE_ID, {"category": BuildingTypeData.Category.COLLECTOR}],
		[GameConfig.BRICK_TYPE_ID,     {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		types.append(td)
	BuildingTypeManager.register_all(types)


func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	_diffusion = autoqfree(ElementDiffusion.new())

	_bm = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	_bm.add_child(pr)
	add_child_autoqfree(_bm)

	_grid.building_manager_ref = _bm

func after_each() -> void:
	_grid = null
	_diffusion = null
	_bm = null

## 无源水体仅自然滑动（不增殖）：格子总数不变，向下移动 1 格，回收由距离/遗弃清理负责
func test_without_source_flows_downward_free() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0  # 源质为 0 也应能流动，证明无源流动免费
	_diffusion.set_essence_service(mock)

	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)

	_diffusion.diffuse_all(_grid)

	assert_false(_grid.has_element(pos), "无源水体原格应腾空")
	assert_true(_grid.has_element(_O + Vector2i(0, 1)), "无源水体应向下滑动 1 格")
	assert_eq(_grid.get_all_element_positions().size(), 1, "无源流动格子总数不变")
	assert_eq(mock.essence, 0.0, "无源流动不应消耗源质")


## 无源水体主方向（向下）被堵时向左右滑动，仍保持格子总数不变
func test_without_source_slides_sideways_when_blocked() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0
	_diffusion.set_essence_service(mock)

	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)
	# 正下方用砖块堵住
	_bm.place_building(_O + Vector2i(0, 1), GameConfig.BRICK_TYPE_ID)

	_diffusion.diffuse_all(_grid)

	assert_false(_grid.has_element(pos), "原格应腾空")
	assert_true(
		_grid.has_element(_O + Vector2i(-1, 0)) or _grid.has_element(_O + Vector2i(1, 0)),
		"主方向被堵时应向左右滑动"
	)
	assert_eq(_grid.get_all_element_positions().size(), 1, "滑动后格子总数不变")


## 回归测试：无源滑动后再被水源接管，水体应继续扩张而非永久冻结
func test_no_source_flow_then_source_reconnect_expands() -> void:
	var mock := _MockEssence.new()
	mock.essence = 100.0
	_diffusion.set_essence_service(mock)

	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)

	# tick 1: 无源免费滑动产生移动后的格
	_diffusion.diffuse_all(_grid)
	var flowed := _O + Vector2i(0, 1)
	assert_true(_grid.has_element(flowed), "无源水体先向下滑动 1 格")

	# 模拟源头接管：把滑动后的格标记为水源
	_grid.mark_as_source(flowed)

	# tick 2: 有源后应继续向下扩张（增殖），不被任何残留状态冻结
	_diffusion.diffuse_all(_grid)
	assert_true(_grid.has_element(_O + Vector2i(0, 2)), "水源接管后应继续向下扩张")

## 回归测试：反应产物在无源滑动时保留存续计时器（防被收集器提前收走）
func test_without_source_flow_keeps_product_timer() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0
	_diffusion.set_essence_service(mock)

	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)
	_grid.mark_as_product(pos, 5)

	_diffusion.diffuse_all(_grid)

	var flowed := _O + Vector2i(0, 1)
	assert_true(_grid.has_element(flowed), "无源水体应向下滑动 1 格")
	assert_true(_grid.is_product(flowed), "滑动后产物存续计时器应保留")
	assert_false(_grid.is_product(pos), "原格产物标记应随元素一并迁移")

func test_with_source_does_not_lose_source_cell() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)
	_grid.mark_as_source(pos)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(pos), "有源水体水源格应保留")

func test_with_source_expands_downward() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)
	_grid.mark_as_source(pos)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(_O + Vector2i(0, 1)), "优先向下方扩张")

func test_with_source_expands_downward_multiple_ticks() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)
	_grid.mark_as_source(pos)

	for _i in range(3):
		_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(_O + Vector2i(0, 3)), "3 tick 后应扩张到 Y=3")
	assert_eq(_grid.get_all_element_positions().size(), 4, "水源格 + 3 次扩张 = 4 格")

func test_spreads_sideways_when_blocked_below() -> void:
	var pos := _O + Vector2i(1, 0)
	_grid.set_element(pos, "water", pos.y)
	_grid.mark_as_source(pos)
	_bm.place_building(_O + Vector2i(1, 1), GameConfig.BRICK_TYPE_ID)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(pos), "水源格应保留")
	assert_true(
		_grid.has_element(_O + Vector2i(0, 0)) or _grid.has_element(_O + Vector2i(2, 0)),
		"正下方被堵时侧边应扩张")

func test_stays_when_trapped_below_source() -> void:
	var pos := _O + Vector2i(2, 0)
	_grid.set_element(pos, "water", pos.y)
	_grid.mark_as_source(pos)
	_bm.place_building(_O + Vector2i(2, 1), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(_O + Vector2i(1, 0), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(_O + Vector2i(3, 0), GameConfig.BRICK_TYPE_ID)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(pos), "被困时水源格应保留")
	assert_eq(_grid.get_all_element_positions().size(), 1, "被困时不应扩张出新的水格")

func test_multiple_sources_expand_faster() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(0, 1)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.mark_as_source(pos_a)
	_grid.set_element(pos_b, "water", pos_b.y)
	_grid.mark_as_source(pos_b)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_element_positions().size(), 4, "双水源应一次扩张 2 格")

func test_adjacent_sources_form_single_body() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_element(pos_a, "water", pos_a.y)
	_grid.mark_as_source(pos_a)
	_grid.set_element(pos_b, "water", pos_b.y)
	_grid.mark_as_source(pos_b)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_element_positions().size(), 4, "相邻两源形成合并水体，一次扩张 2 格 = 4 格总和")


## 无源气体仅自然滑动（不增殖）：格子总数不变，整体上移 1 格，回收由距离/遗弃清理负责
func test_gas_without_source_rises_free() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0  # 源质为 0 也应能流动，证明无源流动免费
	_diffusion.set_essence_service(mock)

	var cells: Array[Vector2i] = [
		Vector2i(5, 5),
		Vector2i(5, 6),
		Vector2i(6, 6),
		Vector2i(6, 7),
	]
	for c: Vector2i in cells:
		_grid.set_element(c, "fire", c.y)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(Vector2i(5, 4)), "无源气体应整体上移 1 格")
	assert_true(_grid.has_element(Vector2i(6, 5)), "无源气体应整体上移 1 格")
	assert_false(_grid.has_element(Vector2i(6, 7)), "原底部格应腾空")
	assert_eq(_grid.get_all_element_positions().size(), 4, "无源流动格子总数不变")
	assert_eq(mock.essence, 0.0, "无源流动不应消耗源质")


# ========== 距离/遗弃清理测试 ==========
# cleanup_abandoned 移除距参照点切比雪夫距离超过 ELEMENT_ABANDON_DISTANCE 的元素


## 远离参照点的元素被清理
func test_cleanup_removes_far_elements() -> void:
	# 用 _O 偏移避开核心占据的 (-1,-1)~(0,0) 区域
	var near_pos := _O + Vector2i(0, 0)
	var far_pos := _O + Vector2i(GameConfig.ELEMENT_ABANDON_DISTANCE + 1, 0)
	_grid.set_element(near_pos, "water", near_pos.y)
	_grid.set_element(far_pos, "water", far_pos.y)

	_diffusion.cleanup_abandoned(_grid)

	assert_true(_grid.has_element(near_pos), "近距离元素应保留")
	assert_false(_grid.has_element(far_pos), "超过阈值的远距离元素应被清理")


## 恰好在阈值内的元素保留，超过阈值才清理（切比雪夫距离 max(|x|,|y|)）
func test_cleanup_chebyshev_threshold() -> void:
	var on_threshold := Vector2i(GameConfig.ELEMENT_ABANDON_DISTANCE, 0)
	# 切比雪夫距离 = max(1000, 1001) = 1001 > 阈值，应被清理
	var beyond_threshold := Vector2i(GameConfig.ELEMENT_ABANDON_DISTANCE, GameConfig.ELEMENT_ABANDON_DISTANCE + 1)
	_grid.set_element(on_threshold, "water", on_threshold.y)
	_grid.set_element(beyond_threshold, "water", beyond_threshold.y)

	_diffusion.cleanup_abandoned(_grid)

	assert_true(_grid.has_element(on_threshold), "切比雪夫距离 = 阈值时应保留")
	assert_false(_grid.has_element(beyond_threshold), "切比雪夫距离 > 阈值时应被清理")


## 自定义参照点：以非原点为参照清理
func test_cleanup_custom_reference() -> void:
	var ref := Vector2i(10, 10)
	var near_pos := Vector2i(10, 12)
	var far_pos := Vector2i(10, 10 + GameConfig.ELEMENT_ABANDON_DISTANCE + 1)
	_grid.set_element(near_pos, "water", near_pos.y)
	_grid.set_element(far_pos, "water", far_pos.y)

	_diffusion.cleanup_abandoned(_grid, ref)

	assert_true(_grid.has_element(near_pos), "距参照点近的元素应保留")
	assert_false(_grid.has_element(far_pos), "距参照点远的元素应被清理")


## 测试9: 源质不足时按实际可负担数量逐个扩张
## 3 个相邻水源（rate=3），但注入 mock 源质仅 2.0（每格成本 1.0）。
## _expand_body 逐个 es.has() 检查，源质不足时停止，应只扩张 2 格而非 0 或 3。
func test_expand_stops_when_essence_insufficient() -> void:
	var mock := _MockEssence.new()
	mock.essence = 2.0
	_diffusion.set_essence_service(mock)

	# 3 个相邻水源构成单连通水体，rate=3
	var sources: Array[Vector2i] = [
		Vector2i(5, 5),
		Vector2i(6, 5),
		Vector2i(7, 5),
	]
	for s: Vector2i in sources:
		_grid.set_element(s, "water", s.y)
		_grid.mark_as_source(s)

	_diffusion.diffuse_all(_grid)

	# 液体向下扩张，候选 Y=6 格有 3 个：(5,6)、(6,6)、(7,6)
	# 源质 2.0 仅够扩张 2 格，第 3 格因 es.has(1.0) 为 false 而跳过
	assert_true(_grid.has_element(Vector2i(5, 6)), "第 1 格应扩张")
	assert_true(_grid.has_element(Vector2i(6, 6)), "第 2 格应扩张")
	assert_false(_grid.has_element(Vector2i(7, 6)), "源质不足时第 3 格不应扩张")
	assert_eq(_grid.get_all_element_positions().size(), 5, "3 原始 + 2 扩张 = 5 格")
	assert_eq(mock.essence, 0.0, "源质应恰好耗尽为 0.0")


# ========== 源头建筑种子产出集成测试 ==========
# 验证 _process_source_buildings：源头放置后由扩散系统创建种子元素（替代旧的 emitter 方向产出）


## 源头未确认类型时不产出种子
func test_source_without_type_confirmed_does_not_produce() -> void:
	var mock := _MockEssence.new()
	mock.essence = 100.0
	_diffusion.set_essence_service(mock)

	# 放置源头建筑（未调用 set_element_type，has_type_selected 返回 false）
	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	_grid.register_source_building(source_pos)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_element_positions().size(), 0, "未确认类型的源头不应产出种子")
	assert_eq(mock.essence, 100.0, "未产出不应消耗源质")


## 源头确认类型后液体向下产出种子
## 注：mock.essence = 0.0 阻止 _expand_body 扩张，从而精确隔离"种子创建"行为。
## 种子创建免费，不消耗源质。
func test_source_confirmed_liquid_produces_seed_downward() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")  # water = LIQUID
	_grid.register_source_building(source_pos)

	_diffusion.diffuse_all(_grid)

	# 液体优先 DOWN：种子应出现在 (5, 6)
	assert_true(_grid.has_element(_O + Vector2i(0, 1)), "液体源头应在下方创建种子")
	assert_eq(_grid.get_element_id(_O + Vector2i(0, 1)), "water", "种子应为 water")
	assert_true(_grid.is_source_pos(_O + Vector2i(0, 1)), "种子应被标记为水源")
	assert_eq(mock.essence, 0.0, "种子创建免费不消耗源质")


## 源头确认类型后气体向上产出种子
func test_source_confirmed_gas_produces_seed_upward() -> void:
	var mock := _MockEssence.new()
	mock.essence = 100.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("fire")  # fire = GAS
	_grid.register_source_building(source_pos)

	_diffusion.diffuse_all(_grid)

	# 气体优先 UP：种子应出现在 (5, 4)
	assert_true(_grid.has_element(_O + Vector2i(0, -1)), "气体源头应在上方创建种子")
	assert_eq(_grid.get_element_id(_O + Vector2i(0, -1)), "fire", "种子应为 fire")


## 源头相邻已有同类型元素时免费维持（不再创建新种子）
## 注：mock.essence = 0.0 阻止 _expand_body 扩张，从而精确验证"免费维持不创建新种子"。
## 免费维持分支不检查源质，直接 mark_as_source 并 continue；扩张因源质不足被阻止。
func test_source_adjacent_same_type_free_maintenance() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)

	# 相邻位置已有 water 元素
	var adjacent: Vector2i = _O + Vector2i(0, 1)
	_grid.set_element(adjacent, "water", adjacent.y)

	_diffusion.diffuse_all(_grid)

	# 相邻 water 被标记为 source（免费维持），不创建新种子，不消耗源质
	assert_true(_grid.is_source_pos(adjacent), "相邻同类型元素应被标记为 source")
	assert_eq(_grid.get_all_element_positions().size(), 1, "不应创建新种子，仅有原相邻元素")
	assert_eq(mock.essence, 0.0, "免费维持不应消耗源质（扩张因源质不足被阻止）")


## 源质不足时源头仍可创建种子（种子免费），但扩张被阻止
func test_source_no_seed_when_essence_insufficient() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.5  # 不足扩张成本 1.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_element_positions().size(), 1, "种子创建免费，应创建 1 个种子")
	assert_eq(mock.essence, 0.5, "种子创建免费不消耗源质")


## 源头被四面包围时找不到空格创建种子
func test_source_no_seed_when_no_space_available() -> void:
	var mock := _MockEssence.new()
	mock.essence = 100.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)

	# 用砖块包围源头，DIR_4 四邻格都被占用
	_bm.place_building(_O + Vector2i(0, 1), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(_O + Vector2i(0, -1), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(_O + Vector2i(1, 0), GameConfig.BRICK_TYPE_ID)
	_bm.place_building(_O + Vector2i(-1, 0), GameConfig.BRICK_TYPE_ID)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_element_positions().size(), 0, "无空格时不应创建种子")
	assert_eq(mock.essence, 100.0, "无空格时不应消耗源质")


## 验证 active_source_positions 过滤：未在激活集合中的源头不产出种子
## 模拟"源头未连通核心"场景：源头已注册到 grid 但不在激活集合中
func test_source_not_in_active_positions_does_not_produce() -> void:
	var mock := _MockEssence.new()
	mock.essence = 100.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)

	# 传入空的激活集合（非 null），表示无源头连通核心
	var empty_active: Dictionary = {}
	_diffusion.diffuse_all(_grid, empty_active)

	assert_eq(_grid.get_all_element_positions().size(), 0, "未在激活集合中的源头不应产出种子")
	assert_eq(mock.essence, 100.0, "未激活源头不应消耗源质")


## 验证 active_source_positions 过滤：在激活集合中的源头正常产出
func test_source_in_active_positions_produces_normally() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)

	# 传入包含该源头的激活集合
	var active: Dictionary = {source_pos: true}
	_diffusion.diffuse_all(_grid, active)

	# 液体优先 DOWN：种子应出现在 (5, 6)
	assert_true(_grid.has_element(_O + Vector2i(0, 1)), "激活集合中的源头应在下方创建种子")
	assert_eq(mock.essence, 0.0, "种子创建免费不消耗源质")


## 验证 active_source_positions 默认 null 时所有源头都产出（向后兼容）
func test_source_default_null_active_processes_all() -> void:
	var mock := _MockEssence.new()
	mock.essence = 0.0
	_diffusion.set_essence_service(mock)

	var source_pos: Vector2i = _O + Vector2i(0, 0)
	_bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = _bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)

	# 不传第二个参数（默认 null），所有已注册源头都应产出
	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_element(_O + Vector2i(0, 1)), "默认 null 时源头应正常产出种子")
	assert_eq(mock.essence, 0.0, "种子创建免费不消耗源质")
