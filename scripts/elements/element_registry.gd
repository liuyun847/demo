extends Node

var _element_types: Dictionary = {}

func _ready() -> void:
	_register_water()
	_register_fire()
	_register_steam()

func get_element_type(element_id: String) -> ElementTypeData:
	return _element_types.get(element_id) as ElementTypeData

func get_all_element_types() -> Dictionary:
	return _element_types

func register_element_type(type_data: ElementTypeData) -> void:
	_element_types[type_data.element_id] = type_data

func _register_water() -> void:
	var water := ElementTypeData.new()
	water.element_id = "water"
	water.display_name = "\u6c34"
	water.color = Color("#4488ff")
	water.state = "liquid"
	water.density = 1.0
	water.reactive = true
	register_element_type(water)

func _register_fire() -> void:
	var fire := ElementTypeData.new()
	fire.element_id = "fire"
	fire.display_name = "\u706b"
	fire.color = Color("#ff6622")
	fire.state = "gas"
	fire.density = 0.3
	fire.reactive = true
	register_element_type(fire)

func _register_steam() -> void:
	var steam := ElementTypeData.new()
	steam.element_id = "steam"
	steam.display_name = "\u84b8\u6c7d"
	steam.color = Color("#ccccdd")
	steam.state = "gas"
	steam.density = 0.2
	steam.reactive = true
	register_element_type(steam)
