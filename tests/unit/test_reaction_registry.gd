extends GutTest

var _registry: ReactionRegistry = null

func before_each() -> void:
	_registry = ReactionRegistry.new()

func test_register_and_find_reaction() -> void:
	_registry.register("water", "fire", "steam", 1.0)
	var rule: Dictionary = _registry.find_reaction("water", "fire")
	assert_false(rule.is_empty(), "应找到 water+fire 反应规则")
	assert_eq(rule["product"], "steam", "产物应为 steam")
	assert_eq(rule["byproduct_essence"], 1.0, "副产物源质应为 1.0")

func test_find_reaction_unordered() -> void:
	_registry.register("water", "fire", "steam", 1.0)
	var rule: Dictionary = _registry.find_reaction("fire", "water")
	assert_false(rule.is_empty(), "fire+water 无序匹配应找到反应规则")
	assert_eq(rule["product"], "steam", "产物应为 steam")

func test_find_reaction_no_match() -> void:
	_registry.register("water", "fire", "steam", 1.0)
	var rule: Dictionary = _registry.find_reaction("water", "steam")
	assert_true(rule.is_empty(), "water+steam 无匹配规则应返回空字典")

func test_get_all_rules() -> void:
	_registry.register("water", "fire", "steam", 1.0)
	_registry.register("water", "steam", "ice", 0.5)
	var rules: Array[Dictionary] = _registry.get_all_rules()
	assert_eq(rules.size(), 2, "应返回 2 条规则")

func test_byproduct_essence_stored() -> void:
	_registry.register("a", "b", "c", 2.5)
	var rule: Dictionary = _registry.find_reaction("a", "b")
	assert_eq(rule["byproduct_essence"], 2.5, "byproduct_essence 应为 2.5")
