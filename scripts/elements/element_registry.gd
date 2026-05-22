extends Node

var _element_types: Dictionary = {}
var _recipes: Array[ReactionRecipe] = []

func _ready() -> void:
	_register_default_elements()
	_register_default_recipes()

func get_element_type(element_id: String) -> ElementTypeData:
	return _element_types.get(element_id) as ElementTypeData

func get_reaction(reactant_a_id: String, reactant_b_id: String) -> String:
	for recipe: ReactionRecipe in _recipes:
		if (recipe.reactant_a_id == reactant_a_id and recipe.reactant_b_id == reactant_b_id) or \
		   (recipe.reactant_a_id == reactant_b_id and recipe.reactant_b_id == reactant_a_id):
			return recipe.product_id
	return ""

func calculate_complexity(complexity_a: int, complexity_b: int) -> int:
	return max(complexity_a, complexity_b) + 1

func calculate_value(element_type: ElementTypeData, complexity: int) -> float:
	return element_type.base_value * get_step_coefficient(complexity)

func get_step_coefficient(step: int) -> float:
	match step:
		1:
			return 1.5
		2:
			return 2.0
		3:
			return 3.0
		_:
			return 1.0

func _register_element_type(type_data: ElementTypeData) -> void:
	_element_types[type_data.element_id] = type_data

func _register_recipe(recipe: ReactionRecipe) -> void:
	_recipes.append(recipe)

func _register_default_elements() -> void:
	var water := ElementTypeData.new()
	water.element_id = "water"
	water.display_name = "\u6c34"
	water.color = Color("#4488ff")
	water.gravity = 0.5
	water.diffusion_rate = 0.6
	water.lateral_priority = 0.7
	water.base_value = 1.0
	_register_element_type(water)

	var fire := ElementTypeData.new()
	fire.element_id = "fire"
	fire.display_name = "\u706b"
	fire.color = Color("#ff6600")
	fire.gravity = -0.8
	fire.diffusion_rate = 0.8
	fire.lateral_priority = 0.3
	fire.base_value = 1.0
	_register_element_type(fire)

	var earth := ElementTypeData.new()
	earth.element_id = "earth"
	earth.display_name = "\u571f"
	earth.color = Color("#8B5E3C")
	earth.gravity = 1.0
	earth.diffusion_rate = 0.0
	earth.lateral_priority = 0.5
	earth.base_value = 1.0
	_register_element_type(earth)

	var lava := ElementTypeData.new()
	lava.element_id = "lava"
	lava.display_name = "\u5ca9\u6d46"
	lava.color = Color("#cc3300")
	lava.gravity = -0.5
	lava.diffusion_rate = 0.3
	lava.lateral_priority = 0.3
	lava.base_value = 2.0
	_register_element_type(lava)

	var rock := ElementTypeData.new()
	rock.element_id = "rock"
	rock.display_name = "\u5ca9\u77f3"
	rock.color = Color("#666666")
	rock.gravity = 1.0
	rock.diffusion_rate = 0.0
	rock.lateral_priority = 0.5
	rock.base_value = 3.0
	_register_element_type(rock)

func _register_default_recipes() -> void:
	var recipe1 := ReactionRecipe.new()
	recipe1.reactant_a_id = "fire"
	recipe1.reactant_b_id = "earth"
	recipe1.product_id = "lava"
	_register_recipe(recipe1)

	var recipe2 := ReactionRecipe.new()
	recipe2.reactant_a_id = "water"
	recipe2.reactant_b_id = "lava"
	recipe2.product_id = "rock"
	_register_recipe(recipe2)
