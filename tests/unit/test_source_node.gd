extends GutTest

var _element_grid: ElementGrid = null
var _source: SourceNode = null
var _SourceScript: GDScript = null

func before_all() -> void:
	_SourceScript = load("res://scripts/building/source_node.gd") as GDScript

func before_each() -> void:
	_element_grid = autoqfree(ElementGrid.new()) as ElementGrid
	add_child_autoqfree(_element_grid)
	_source = autoqfree(_SourceScript.new()) as SourceNode
	_source.grid_position = Vector2i(0, 0)
	add_child_autoqfree(_source)

func test_source_default_water() -> void:
	assert_eq(_source.element_type_id, "water", "默认 element_type_id 应为 water")
	assert_false(_source.has_type_selected(), "未确认类型前 has_type_selected 应返回 false")

func test_source_type_confirmed_after_set() -> void:
	_source.set_element_type("fire")
	assert_true(_source.has_type_selected(), "set_element_type 后 has_type_selected 应返回 true")
	assert_eq(_source.element_type_id, "fire", "element_type_id 应为 fire")

func test_source_has_required_properties() -> void:
	assert_eq(_source.element_type_id, "water", "默认应为 water")
	assert_eq(GameConfig.SOURCE_ESSENCE_COST_PER_TICK, 1.0, "SOURCE_ESSENCE_COST_PER_TICK 应为 1.0")

func test_source_get_building_name() -> void:
	assert_eq(_source.get_building_name(), "源头(水)", "源头名称应为源头(水)")

func test_source_default_has_no_direction_concept() -> void:
	# 回归保护：源头不再有方向概念，相关属性/方法不应存在
	assert_false(_source.has_method("set_output_direction"), "SourceNode 不应有 set_output_direction 方法")
	assert_false(_source.has_method("get_default_direction"), "SourceNode 不应有 get_default_direction 方法")
	assert_false("output_direction" in _source, "SourceNode 不应有 output_direction 属性")

## 回归保护：MapInputHandler 不再定义 _EMITTER_DIRS 常量
func test_no_emitter_dirs_constant_in_input_handler() -> void:
	var handler_script := load("res://scripts/grid/map_input_handler.gd") as GDScript
	var constants := handler_script.get_script_constant_map()
	assert_false(constants.has("_EMITTER_DIRS"), "_EMITTER_DIRS 常量应已被移除")

## 回归保护：BuildingTypeData.Category 不再包含 EMITTER，已替换为 SOURCE
func test_category_enum_has_source_not_emitter() -> void:
	var cat_constants: Dictionary = BuildingTypeData.Category
	# BuildingTypeData.Category 是枚举，验证其键集合
	var keys: Array = cat_constants.keys()
	assert_true(keys.has("SOURCE"), "Category 应包含 SOURCE")
	assert_false(keys.has("EMITTER"), "Category 不应再包含 EMITTER")
