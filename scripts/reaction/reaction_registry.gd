class_name ReactionRegistry
extends RefCounted

## 反应规则列表: Array[Dictionary]
var _rules: Array[Dictionary] = []

## 注册反应规则（reactants 无序匹配）
func register(reactant_a: String, reactant_b: String, product: String, byproduct_essence: float = 0.0) -> void:
	# 检查是否已存在相同反应对的规则，避免重复注册产生死规则
	var existing: Dictionary = find_reaction(reactant_a, reactant_b)
	if not existing.is_empty():
		push_warning("ReactionRegistry: 反应规则 %s + %s 已存在，跳过重复注册" % [reactant_a, reactant_b])
		return
	_rules.append({
		"reactants": [reactant_a, reactant_b],
		"product": product,
		"byproduct_essence": byproduct_essence,
	})

## 查找匹配的反应规则，返回规则 dict，无匹配时返回空 dict
func find_reaction(element_a: String, element_b: String) -> Dictionary:
	for rule: Dictionary in _rules:
		var reactants: Array = rule["reactants"]
		if (reactants[0] == element_a and reactants[1] == element_b) or \
		   (reactants[0] == element_b and reactants[1] == element_a):
			return rule
	return {}

## 获取所有规则
func get_all_rules() -> Array[Dictionary]:
	return _rules
