extends GutTest

## 增量模拟性能回归守护（方向 A）：
## 大水体/大区域场景下，脏区域增量模式必须远快于全量扫描（数量级差距）。
## 若脏区域跟踪被破坏（如全量标脏、跳过失效），本测试将失败告警。
## 注：时间基准受机器影响，但实测差距为 3 个数量级，阈值留了极大余量（50x）。
## 注：含水源标记的区域（协调器每 tick 清空重建水源标记）每 tick 仍会整体重算，
## 不在增量加速范围内，因此本基准只覆盖无源稳定水体与反应扫描两类真实增量场景。

const _O: Vector2i = Vector2i(10, 10)

var _grid: ElementGrid = null
var _diffusion: ElementDiffusion = null
var _bm: BuildingManager = null

class _MockEssence:
	var essence: float = 0.0
	func add(amount: float) -> void:
		essence += amount
	func subtract(amount: float) -> float:
		essence -= amount
		return amount
	func has(amount: float) -> bool:
		return essence >= amount

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	_bm = autoqfree(BuildingManager.new())
	_grid.building_manager_ref = _bm
	_diffusion = autoqfree(ElementDiffusion.new())
	_diffusion.set_essence_service(_MockEssence.new())

## 构建 40x50=2000 格、四周砖块围死、无源的稳定水体（不流动）
func _build_stable_pool() -> void:
	for x in range(_O.x - 1, _O.x + 41):
		_bm.place_building(Vector2i(x, _O.y - 1), GameConfig.BRICK_TYPE_ID)
		_bm.place_building(Vector2i(x, _O.y + 50), GameConfig.BRICK_TYPE_ID)
	for y in range(_O.y, _O.y + 50):
		_bm.place_building(Vector2i(_O.x - 1, y), GameConfig.BRICK_TYPE_ID)
		_bm.place_building(Vector2i(_O.x + 40, y), GameConfig.BRICK_TYPE_ID)
	for x in range(_O.x, _O.x + 40):
		for y in range(_O.y, _O.y + 50):
			_grid.set_element(Vector2i(x, y), "water", y)
	_grid.take_dirty()

func _bench_legacy_vs_incremental() -> Array:
	# 预热
	for i in 10:
		_diffusion.diffuse_all(_grid)
		_diffusion.diffuse_all(_grid, null, [])
	var t0 := Time.get_ticks_usec()
	for i in 100:
		_diffusion.diffuse_all(_grid)
	var legacy_us: float = (Time.get_ticks_usec() - t0) / 100.0
	_grid.take_dirty()
	var t1 := Time.get_ticks_usec()
	var empty: Array[Vector2i] = []
	for i in 100:
		_diffusion.diffuse_all(_grid, null, empty)
		_grid.take_dirty()
	var incr_us: float = (Time.get_ticks_usec() - t1) / 100.0
	return [legacy_us, incr_us]

## 稳定无源水体：无变化 tick 应从 ~7ms 降到 ~0（实测 2473x）
func test_bench_stable_pool_incremental_far_faster() -> void:
	_build_stable_pool()
	var r: Array = _bench_legacy_vs_incremental()
	var legacy_us: float = r[0]
	var incr_us: float = r[1]
	print("BENCH stable-pool cells=2000 legacy=%.0fus/tick incremental=%.0fus/tick speedup=%.1fx" % [
		legacy_us, incr_us, legacy_us / maxf(incr_us, 0.001)])
	assert_lt(incr_us, legacy_us / 50.0, "稳定水体增量模式应远快于全量扫描（脏区域跳过失效？）")

## 反应扫描：无规则 2000 格纯扫描成本，单脏格增量应远快于全量（实测 2135x）
func test_bench_reaction_scan_incremental_far_faster() -> void:
	for x in range(_O.x, _O.x + 40):
		for y in range(_O.y, _O.y + 25):
			_grid.set_element(Vector2i(x, y), "water", y)
			_grid.set_element(Vector2i(x, y + 25), "fire", y + 25)
	_grid.take_dirty()
	var registry := ReactionRegistry.new()
	var processor := ReactionProcessor.new(registry, _grid, _MockEssence.new())
	for i in 10:
		processor.process_all()
		processor.process_all([])
	var t0 := Time.get_ticks_usec()
	for i in 100:
		processor.process_all()
	var full_us: float = (Time.get_ticks_usec() - t0) / 100.0
	_grid.take_dirty()
	var t1 := Time.get_ticks_usec()
	var one: Array[Vector2i] = [_O]
	for i in 100:
		processor.process_all(one)
	var incr_us: float = (Time.get_ticks_usec() - t1) / 100.0
	print("BENCH reaction-scan cells=2000 full=%.0fus/tick incremental(1cell)=%.1fus/tick speedup=%.1fx" % [
		full_us, incr_us, full_us / maxf(incr_us, 0.001)])
	assert_lt(incr_us, full_us / 50.0, "增量反应扫描应远快于全量扫描")
