extends Node

var _element_types: Dictionary = {}

func _ready() -> void:
	_register_water()

func get_element_type(element_id: String) -> ElementTypeData:
	return _element_types.get(element_id) as ElementTypeData

func _register_element_type(type_data: ElementTypeData) -> void:
	_element_types[type_data.element_id] = type_data

func _register_water() -> void:
	var water := ElementTypeData.new()
	water.element_id = "water"
	water.display_name = "\u6c34"
	water.color = Color("#4488ff")
	_register_element_type(water)
