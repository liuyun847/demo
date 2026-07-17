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

func test_register_duplicate_skips() -> void:
	_registry.register("water", "fire", "steam", 1.0)
	# 重复注册相同反应对（同序）应跳过并 push_warning
	_registry.register("water", "fire", "ice", 2.0)
	assert_push_warning("已存在", "同序重复注册应 push_warning")
	# 规则数应仍为 1（跳过重复，不追加）
	var rules: Array[Dictionary] = _registry.get_all_rules()
	assert_eq(rules.size(), 1, "重复注册应跳过，规则数仍为 1")
	# 应保留首次注册的规则，不被覆盖
	var rule: Dictionary = _registry.find_reaction("water", "fire")
	assert_eq(rule["product"], "steam", "应保留首次注册的产物 steam，不被覆盖为 ice")
	assert_eq(rule["byproduct_essence"], 1.0, "应保留首次注册的 byproduct_essence 1.0")
	# 反序注册相同反应对也应跳过（无序匹配）
	_registry.register("fire", "water", "ice", 3.0)
	assert_push_warning("已存在", "反序重复注册应 push_warning")
	assert_eq(_registry.get_all_rules().size(), 1, "反序重复注册也应跳过")
