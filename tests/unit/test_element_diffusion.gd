extends GutTest

const _BM: GDScript = preload("res://scripts/building/building_manager.gd")
const _PRS: GDScript = preload("res://scripts/building/pipe_render_system.gd")

var _grid: ElementGrid = null
var _diffusion: ElementDiffusion = null
var _bm: BuildingManager = null

# 偏移量，避开 BuildingManager 核心占据的 (0,0)-(1,1) 区域
const _O: Vector2i = Vector2i(5, 5)


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.pipe_type_id):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.pipe_type_id,      {"is_pipe": true}],
		[GameConfig.emitter_type_id,   {"is_emitter": true}],
		[GameConfig.collector_type_id, {"is_collector": true}],
		[GameConfig.brick_type_id,     {}],
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
	_grid.set_fluid(pos, pos.y)

	_diffusion.diffuse_all(_grid)

	var count: int = _grid.get_all_fluid_positions().size()
	assert_eq(count, 0, "无源水体应逐渐缩小直至消失")

func test_with_source_does_not_lose_source_cell() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_fluid(pos, pos.y)
	_grid.mark_as_source(pos)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(pos), "有源水体水源格应保留")

func test_with_source_expands_downward() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_fluid(pos, pos.y)
	_grid.mark_as_source(pos)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(_O + Vector2i(0, 1)), "优先向下方扩张")

func test_with_source_expands_downward_multiple_ticks() -> void:
	var pos := _O + Vector2i(0, 0)
	_grid.set_fluid(pos, pos.y)
	_grid.mark_as_source(pos)

	for _i in range(3):
		_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(_O + Vector2i(0, 3)), "3 tick 后应扩张到 Y=3")
	assert_eq(_grid.get_all_fluid_positions().size(), 4, "水源格 + 3 次扩张 = 4 格")

func test_spreads_sideways_when_blocked_below() -> void:
	var pos := _O + Vector2i(1, 0)
	_grid.set_fluid(pos, pos.y)
	_grid.mark_as_source(pos)
	_bm.place_building(_O + Vector2i(1, 1), GameConfig.brick_type_id)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(pos), "水源格应保留")
	assert_true(
		_grid.has_fluid(_O + Vector2i(0, 0)) or _grid.has_fluid(_O + Vector2i(2, 0)),
		"正下方被堵时侧边应扩张")

func test_stays_when_trapped_below_source() -> void:
	var pos := _O + Vector2i(2, 0)
	_grid.set_fluid(pos, pos.y)
	_grid.mark_as_source(pos)
	_bm.place_building(_O + Vector2i(2, 1), GameConfig.brick_type_id)
	_bm.place_building(_O + Vector2i(1, 0), GameConfig.brick_type_id)
	_bm.place_building(_O + Vector2i(3, 0), GameConfig.brick_type_id)

	_diffusion.diffuse_all(_grid)

	assert_true(_grid.has_fluid(pos), "被困时水源格应保留")
	assert_eq(_grid.get_all_fluid_positions().size(), 1, "被困时不应扩张出新的水格")

func test_multiple_sources_expand_faster() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(0, 1)
	_grid.set_fluid(pos_a, pos_a.y)
	_grid.mark_as_source(pos_a)
	_grid.set_fluid(pos_b, pos_b.y)
	_grid.mark_as_source(pos_b)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_fluid_positions().size(), 4, "双水源应一次扩张 2 格")

func test_adjacent_sources_form_single_body() -> void:
	var pos_a := _O + Vector2i(0, 0)
	var pos_b := _O + Vector2i(1, 0)
	_grid.set_fluid(pos_a, pos_a.y)
	_grid.mark_as_source(pos_a)
	_grid.set_fluid(pos_b, pos_b.y)
	_grid.mark_as_source(pos_b)

	_diffusion.diffuse_all(_grid)

	assert_eq(_grid.get_all_fluid_positions().size(), 4, "相邻两源形成合并水体，一次扩张 2 格 = 4 格总和")
