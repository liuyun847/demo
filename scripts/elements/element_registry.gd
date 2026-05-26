extends Node

var _element_types: Dictionary = {}

func _ready() -> void:
	_register_water()

func get_element_type(element_id: String) -> ElementTypeData:
	return _element_types.get(element_id) as ElementTypeData

func calculate_value(element_type: ElementTypeData, _complexity: int = 1) -> float:
	return element_type.base_value

func _register_element_type(type_data: ElementTypeData) -> void:
	_element_types[type_data.element_id] = type_data

func _register_water() -> void:
	var water := ElementTypeData.new()
	water.element_id = "water"
	water.display_name = "\u6c34"
	water.color = Color("#4488ff")
	water.gravity = 0.5
	water.diffusion_rate = 0.6
	water.base_value = 1.0
	_register_element_type(water)