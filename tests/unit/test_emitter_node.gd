extends GutTest

var _element_grid: ElementGrid = null
var _emitter: EmitterNode = null
var _EmitterScript: GDScript = null

func before_all() -> void:
	_EmitterScript = load("res://scripts/building/emitter_node.gd") as GDScript

func before_each() -> void:
	_element_grid = autoqfree(ElementGrid.new()) as ElementGrid
	add_child_autoqfree(_element_grid)
	_emitter = autoqfree(_EmitterScript.new()) as EmitterNode
	_emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(_emitter)

func test_emitter_default_water() -> void:
	assert_eq(_emitter.element_type_id, "water", "默认 element_type_id 应为 water")
	assert_false(_emitter.has_type_selected(), "未确认类型前 has_type_selected 应返回 false")

func test_emitter_type_confirmed_after_set() -> void:
	_emitter.set_element_type("fire")
	assert_true(_emitter.has_type_selected(), "set_element_type 后 has_type_selected 应返回 true")
	assert_eq(_emitter.element_type_id, "fire", "element_type_id 应为 fire")

func test_emitter_has_required_properties() -> void:
	assert_eq(_emitter.element_type_id, "water", "默认应为 water")
	assert_eq(GameConfig.EMITTER_ESSENCE_COST_PER_TICK, 1.0, "EMITTER_ESSENCE_COST_PER_TICK 应为 1.0")

func test_emitter_default_direction_down() -> void:
	var emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(emitter)
	assert_eq(emitter.get_default_direction(), Vector2i(0, 1), "默认方向应向下")

func test_emitter_get_building_name() -> void:
	assert_eq(_emitter.get_building_name(), "喷口(水)", "喷口名称应为喷口(水)")

func test_set_output_direction() -> void:
	assert_eq(_emitter.output_direction, Vector2i(0, 1), "默认方向向下")
	_emitter.set_output_direction(Vector2i(0, -1))
	assert_eq(_emitter.output_direction, Vector2i(0, -1), "set_output_direction 应更新方向为上")

## 回归保护：MapInputHandler._EMITTER_DIRS[0] 必须等于 EmitterNode 默认方向 DOWN
# 历史问题：曾误改为 GridCoordinate.DIR_4（UP 优先），导致旋转方向反转、默认朝向与 EmitterNode 不一致
func test_emitter_dirs_index_0_matches_node_default() -> void:
	var handler_script := load("res://scripts/grid/map_input_handler.gd") as GDScript
	var constants := handler_script.get_script_constant_map()
	assert_true(constants.has("_EMITTER_DIRS"), "_EMITTER_DIRS 常量应存在")
	var dirs: Array = constants["_EMITTER_DIRS"]
	assert_eq(dirs.size(), 4, "_EMITTER_DIRS 应有 4 个方向")
	assert_eq(dirs[0], Vector2i(0, 1), "_EMITTER_DIRS[0] 应为 DOWN(0,1)")
	# 与 EmitterNode 默认方向一致
	var fresh_emitter: EmitterNode = _EmitterScript.new() as EmitterNode
	fresh_emitter.grid_position = Vector2i(0, 0)
	add_child_autoqfree(fresh_emitter)
	assert_eq(dirs[0], fresh_emitter.output_direction, "_EMITTER_DIRS[0] 应与 EmitterNode 默认方向一致")
	# 旋转序列应为逆时针 [DOWN, LEFT, UP, RIGHT]
	assert_eq(dirs[1], Vector2i(-1, 0), "_EMITTER_DIRS[1] 应为 LEFT(-1,0)")
	assert_eq(dirs[2], Vector2i(0, -1), "_EMITTER_DIRS[2] 应为 UP(0,-1)")
	assert_eq(dirs[3], Vector2i(1, 0), "_EMITTER_DIRS[3] 应为 RIGHT(1,0)")
