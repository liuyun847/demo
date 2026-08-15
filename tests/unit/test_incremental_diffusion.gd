extends GutTest

## 增量模拟（方向 A：脏区域增量更新）的单元测试：
## 验证 ElementGrid 脏区域跟踪、增量扩散仅重算变化区域、增量反应扫描。

const _O: Vector2i = Vector2i(5, 5)

var _grid: ElementGrid = null
var _diffusion: ElementDiffusion = null

func before_each() -> void:
	_grid = autoqfree(ElementGrid.new())
	# 注入未 add_child 的 BuildingManager 实例：
	# 其 _ready() 不会触发，get_building_node 返回 null，使 is_building_at 返回 false
	_grid.building_manager_ref = autoqfree(BuildingManager.new())
	_diffusion = autoqfree(ElementDiffusion.new())

func after_each() -> void:
	_grid = null
	_diffusion = null


# ========== 脏区域跟踪 ==========

## set_element 标记脏区域，take_dirty 取走并清空
func test_dirty_tracking_set_and_take() -> void:
	_grid.set_element(_O, "water", _O.y)
	assert_gt(_grid.get_dirty_count(), 0, "set_element 后应有脏区域")
	var dirty: Array[Vector2i] = _grid.take_dirty()
	assert_eq(_grid.get_dirty_count(), 0, "take_dirty 后应清空")
	assert_true(dirty.has(_O), "脏区域应包含放置位置")
	assert_true(dirty.has(_O + Vector2i(0, 1)), "脏区域应包含四邻（下方）")

## remove_element 标记脏区域
func test_dirty_tracking_remove() -> void:
	_grid.set_element(_O, "water", _O.y)
	_grid.take_dirty()
	_grid.remove_element(_O)
	assert_gt(_grid.get_dirty_count(), 0, "remove_element 后应有脏区域")

## move_element 同时标记原位置与目标位置
func test_dirty_tracking_move_marks_both() -> void:
	_grid.set_element(_O, "water", _O.y)
	_grid.take_dirty()
	var to := _O + Vector2i(0, 1)
	_grid.move_element(_O, to)
	var dirty: Array[Vector2i] = _grid.take_dirty()
	assert_true(dirty.has(_O), "移动后原位置应标记脏")
	assert_true(dirty.has(to), "移动后目标位置应标记脏")

## 水源标记变化（mark_as_source）标记脏区域
func test_dirty_tracking_mark_source() -> void:
	_grid.set_element(_O, "water", _O.y)
	_grid.take_dirty()
	_grid.mark_as_source(_O)
	assert_gt(_grid.get_dirty_count(), 0, "新增水源标记后应有脏区域")

## 清空水源标记时对被清除的水源格标记脏区域（源头切换后旧体需重算）
func test_dirty_tracking_clear_sources_marks() -> void:
	_grid.set_element(_O, "water", _O.y)
	_grid.mark_as_source(_O)
	_grid.take_dirty()
	_grid.clear_all_sources()
	var dirty: Array[Vector2i] = _grid.take_dirty()
	assert_true(dirty.has(_O), "水源被清空后应标记脏区域")


# ========== 增量扩散 ==========

## 增量模式仅处理脏区域涉及的连通区域，未变化区域整体跳过
func test_incremental_diffuse_only_dirty_region() -> void:
	var a := _O + Vector2i(0, 0)
	var b := _O + Vector2i(5, 0)  # 独立无源水体
	_grid.set_element(a, "water", a.y)
	_grid.set_element(b, "water", b.y)
	_grid.take_dirty()

	# 仅 a 在脏区域：a 应下滑，b 保持原位
	var dirty: Array[Vector2i] = [a]
	_diffusion.diffuse_all(_grid, null, dirty)

	assert_false(_grid.has_element(a), "脏区域水体应下滑腾空原格")
	assert_true(_grid.has_element(a + Vector2i(0, 1)), "脏区域水体应下滑 1 格")
	assert_true(_grid.has_element(b), "未变化区域应整体跳过")

## 空脏区域且无源头时不做任何处理
func test_incremental_diffuse_empty_dirty_noop() -> void:
	var a := _O + Vector2i(0, 0)
	_grid.set_element(a, "water", a.y)
	_grid.take_dirty()
	var empty: Array[Vector2i] = []
	_diffusion.diffuse_all(_grid, null, empty)
	assert_true(_grid.has_element(a), "空脏区域时水体不应移动")

## 增量模式下源头仍每 tick 产出种子（脏区域为空也会创建种子并处理）
func test_incremental_diffuse_source_still_produces_seed() -> void:
	var source_pos: Vector2i = _O + Vector2i(0, 0)
	var bm: BuildingManager = _grid.building_manager_ref
	bm.place_building(source_pos, GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = bm.get_building_node(source_pos) as SourceNode
	source_node.set_element_type("water")
	_grid.register_source_building(source_pos)
	_grid.take_dirty()

	var empty: Array[Vector2i] = []
	_diffusion.diffuse_all(_grid, null, empty)

	# 液体源头应在下方创建种子（种子创建免费）
	assert_true(_grid.has_element(_O + Vector2i(0, 1)), "源头应创建种子")
	assert_true(_grid.is_source_pos(_O + Vector2i(0, 1)), "种子应被标记为水源")


# ========== 增量反应 ==========

## 仅扫描脏区域位置即可触发反应（脏区域含四邻，覆盖所有相邻对）
func test_incremental_reaction_scan_dirty() -> void:
	var registry := ReactionRegistry.new()
	registry.register("water", "fire", "steam", 0.0)
	var processor := ReactionProcessor.new(registry, _grid, null)
	var a := _O + Vector2i(0, 0)
	var b := _O + Vector2i(1, 0)
	_grid.set_element(a, "water", a.y)
	_grid.set_element(b, "fire", b.y)

	var dirty: Array[Vector2i] = [a]
	processor.process_all(dirty)

	assert_eq(_grid.get_all_element_positions().size(), 1, "反应后应只剩 1 个产物")
	assert_eq(_grid.get_element_id(a), "steam", "产物应为 steam（water 密度更大占位）")
	assert_true(_grid.is_product(a), "产物应有存续标记")

## 空脏区域时反应扫描不做任何处理
func test_incremental_reaction_empty_dirty_noop() -> void:
	var registry := ReactionRegistry.new()
	registry.register("water", "fire", "steam", 0.0)
	var processor := ReactionProcessor.new(registry, _grid, null)
	var a := _O + Vector2i(0, 0)
	var b := _O + Vector2i(1, 0)
	_grid.set_element(a, "water", a.y)
	_grid.set_element(b, "fire", b.y)

	var empty: Array[Vector2i] = []
	processor.process_all(empty)

	assert_eq(_grid.get_all_element_positions().size(), 2, "空脏区域时不应触发反应")
