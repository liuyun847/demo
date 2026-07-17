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
		[GameConfig.EMITTER_TYPE_ID,   {"category": BuildingTypeData.Category.EMITTER}],
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

func test_without_source_vanishes() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_element(pos, "water", pos.y)

	_diffusion.diffuse_all(_grid)

	var count: int = _grid.get_all_element_positions().size()
	assert_eq(count, 0, "无源水体应逐渐缩小直至消失")

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


## 测试3: 无源气体从边缘均匀收缩，不定向消失
## 使用 fire(GAS) 构造阶梯形连通区域，各格 (x+y) 互不相同：
## (5,5)=10, (5,6)=11, (6,6)=12, (6,7)=13，均为边缘格。
## _shrink_uniform 按 (x+y) 升序确定性移除前 3 格（rate=max(3,4/10)=3）。
func test_gas_shrink_uniform_by_x_plus_y() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(5, 5),
		Vector2i(5, 6),
		Vector2i(6, 6),
		Vector2i(6, 7),
	]
	for c: Vector2i in cells:
		_grid.set_element(c, "fire", c.y)

	_diffusion.diffuse_all(_grid)

	# (x+y) 最小的 3 格被移除：(5,5)、(5,6)、(6,6)
	assert_false(_grid.has_element(Vector2i(5, 5)), "(5,5) x+y=10 应被移除")
	assert_false(_grid.has_element(Vector2i(5, 6)), "(5,6) x+y=11 应被移除")
	assert_false(_grid.has_element(Vector2i(6, 6)), "(6,6) x+y=12 应被移除")
	# (x+y) 最大的 (6,7) 应保留
	assert_true(_grid.has_element(Vector2i(6, 7)), "(6,7) x+y=13 应保留")
	assert_eq(_grid.get_all_element_positions().size(), 1, "4 格气体收缩 3 格后应剩 1 格")


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
