extends GutTest

var _bm: Node2D = null
var _reactor: ReactionCoordinator = null

func before_each() -> void:
	preload("res://scripts/building/container_node.gd")
	preload("res://scripts/building/pipe_node.gd")
	preload("res://scripts/building/brick_node.gd")
	preload("res://scripts/resources/building_data.gd")

	var bm_script: GDScript = preload("res://scripts/building/building_manager.gd")
	_bm = autoqfree(bm_script.new())
	_bm.name = "BuildingManager"
	_bm.unique_name_in_owner = true

	var pipe_render: PipeRenderSystem = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	pipe_render.name = "PipeRenderSystem"
	_bm.add_child(pipe_render)

	var gp: GhostPreviewManager = autoqfree(load("res://scripts/building/ghost_preview_manager.gd").new())
	gp.name = "GhostPreviewManager"
	_bm.add_child(gp)

	add_child_autoqfree(_bm)

	_reactor = _bm.get_node("ReactionCoordinator") as ReactionCoordinator
	assert_not_null(_reactor, "ReactionCoordinator 应已创建")

	EssencePool.set_value(100.0)

func _grid() -> ElementGrid:
	return _reactor._element_grid

func _setup_emitter_with_type(emitter_pos: Vector2i, type_id: String) -> void:
	_bm.place_building(emitter_pos, GameConfig.emitter_type_id)
	var node: Node = _bm.get_building_node(emitter_pos)
	if node is EmitterNode:
		node.set_element_type(type_id)

func test_emitter_outputs_element_when_connected() -> void:
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_setup_emitter_with_type(Vector2i(0, 2), "water")

	_reactor._on_tick()

	var all_positions: Array[Vector2i] = _grid().get_all_element_positions()
	assert_ne(all_positions.size(), 0, "tick 后应有元素")
	if all_positions.size() > 0:
		var element: ElementData = _grid().get_element(all_positions[0])
		assert_not_null(element, "元素数据不应为空")
		assert_eq(element.element_type.element_id, "water", "应是水元素")

func test_emitter_reduces_essence_on_output() -> void:
	EssencePool.set_value(10.0)
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_setup_emitter_with_type(Vector2i(0, 2), "water")

	_reactor._on_tick()

	assert_lt(EssencePool.essence, 10.0, "输出应消耗源质")

func test_collector_collects_element_and_increases_essence() -> void:
	EssencePool.set_value(50.0)
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_bm.place_building(Vector2i(0, 2), GameConfig.collector_type_id)

	_grid().set_element(Vector2i(0, 3), _create_element("rock", 3))

	_reactor._on_tick()

	assert_null(_grid().get_element(Vector2i(0, 3)), "收集后岩石应被移除")
	assert_gt(EssencePool.essence, 50.0, "收集应增加源质")

func test_full_chain_emitter_to_collector() -> void:
	EssencePool.set_value(100.0)

	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_setup_emitter_with_type(Vector2i(1, 1), "water")
	_bm.place_building(Vector2i(0, 2), GameConfig.collector_type_id)

	_reactor._on_tick()

	assert_ne(EssencePool.essence, 100.0, "源质应已变化（消耗或收集）")

	var all_positions: Array[Vector2i] = _grid().get_all_element_positions()
	assert_true(all_positions.size() > 0 or EssencePool.essence != 100.0,
		"有元素产出或源质已变化")

func test_insufficient_essence_scales_output() -> void:
	EssencePool.set_value(0.5)
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_setup_emitter_with_type(Vector2i(0, 2), "water")

	_reactor._on_tick()

	assert_eq(EssencePool.essence, 0.0, "源质不足时消耗后归零")

func test_emitter_does_not_output_to_building_cell() -> void:
	EssencePool.set_value(100.0)
	_bm.place_building(Vector2i(0, 0), GameConfig.pipe_type_id)
	_bm.place_building(Vector2i(0, 1), GameConfig.container_type_id)
	_setup_emitter_with_type(Vector2i(0, 2), "water")
	_bm.place_building(Vector2i(0, 3), GameConfig.brick_type_id)

	_reactor._on_tick()

	assert_null(_grid().get_element(Vector2i(0, 3)), "目标格子有建筑时应不输出")

func _create_element(type_id: String, complexity: int) -> ElementData:
	var element_type: ElementTypeData = ElementRegistry.get_element_type(type_id)
	var element := ElementData.new()
	element.element_type = element_type
	element.complexity = complexity
	return element
