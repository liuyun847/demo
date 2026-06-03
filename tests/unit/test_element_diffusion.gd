extends GutTest

const _BM: GDScript = preload("res://scripts/building/building_manager.gd")
const _PRS: GDScript = preload("res://scripts/building/pipe_render_system.gd")

var _grid: ElementGrid = null
var _diffusion: ElementDiffusion = null
var _bm: BuildingManager = null

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
	_grid.set_fluid(Vector2i(0, 0), 0)

	_diffusion.diffuse_all(_grid)

	var count: int = _grid.get_all_fluid_positions().size()
	assert_eq(count, 0, "无源水体应逐渐缩小直至消失")

func test_with_source_does_not_lose_source_cell() -> void:
	_grid.set_fluid(Vector2i(0, 0), 0)
	_grid.mark_as_source(Vector2i(0, 0))

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(Vector2i(0, 0)), "有源水体水源格应保留")

func test_with_source_expands_downward() -> void:
	_grid.set_fluid(Vector2i(0, 0), 0)
	_grid.mark_as_source(Vector2i(0, 0))

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(Vector2i(0, 1)), "优先向下方扩张")

func test_with_source_expands_downward_multiple_ticks() -> void:
	_grid.set_fluid(Vector2i(0, 0), 0)
	_grid.mark_as_source(Vector2i(0, 0))

	for _i in range(3):
		_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(Vector2i(0, 3)), "3 tick 后应扩张到 Y=3")
	assert_eq(_grid.get_all_fluid_positions().size(), 4, "水源格 + 3 次扩张 = 4 格")

func test_spreads_sideways_when_blocked_below() -> void:
	_grid.set_fluid(Vector2i(1, 0), 0)
	_grid.mark_as_source(Vector2i(1, 0))
	_bm.place_building(Vector2i(1, 1), GameConfig.brick_type_id)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(Vector2i(1, 0)), "水源格应保留")
	assert_true(
		_grid.has_fluid(Vector2i(0, 0)) or _grid.has_fluid(Vector2i(2, 0)),
		"正下方被堵时侧边应扩张")

func test_stays_when_trapped_below_source() -> void:
	_grid.set_fluid(Vector2i(2, 0), 0)
	_grid.mark_as_source(Vector2i(2, 0))
	_bm.place_building(Vector2i(2, 1), GameConfig.brick_type_id)
	_bm.place_building(Vector2i(1, 0), GameConfig.brick_type_id)
	_bm.place_building(Vector2i(3, 0), GameConfig.brick_type_id)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(Vector2i(2, 0)), "被困时水源格应保留")
	assert_eq(_grid.get_all_fluid_positions().size(), 1, "被困时不应扩张出新的水格")

func test_multiple_sources_expand_faster() -> void:
	_grid.set_fluid(Vector2i(0, 0), 0)
	_grid.mark_as_source(Vector2i(0, 0))
	_grid.set_fluid(Vector2i(0, 1), 0)
	_grid.mark_as_source(Vector2i(0, 1))

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_fluid_positions().size(), 4, "双水源应一次扩张 2 格")

func test_adjacent_sources_form_single_body() -> void:
	_grid.set_fluid(Vector2i(0, 0), 0)
	_grid.mark_as_source(Vector2i(0, 0))
	_grid.set_fluid(Vector2i(1, 0), 0)
	_grid.mark_as_source(Vector2i(1, 0))

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_fluid_positions().size(), 4, "相邻两源形成合并水体，一次扩张 2 格 = 4 格总和")
