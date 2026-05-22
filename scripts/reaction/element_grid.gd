class_name ElementGrid
extends Node

var _elements: Dictionary = {}
var building_manager_ref: BuildingManager = null

func set_element(pos: Vector2i, element: ElementData) -> bool:
	if _elements.has(pos):
		return false
	if is_building_at(pos):
		return false
	_elements[pos] = element
	EventBus.element_spawned.emit(pos, element.element_type.element_id)
	return true

func get_element(pos: Vector2i) -> ElementData:
	return _elements.get(pos) as ElementData

func remove_element(pos: Vector2i) -> ElementData:
	var element: ElementData = _elements.get(pos) as ElementData
	if element:
		_elements.erase(pos)
		EventBus.element_removed.emit(pos, element.element_type.element_id)
	return element

func has_element(pos: Vector2i) -> bool:
	return _elements.has(pos)

func is_position_available(pos: Vector2i) -> bool:
	return not _elements.has(pos) and not is_building_at(pos)

func is_building_at(pos: Vector2i) -> bool:
	if building_manager_ref == null:
		return false
	return building_manager_ref.get_building_node(pos) != null

func get_all_element_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for key: Variant in _elements:
		positions.append(key as Vector2i)
	return positions

func clear_all() -> void:
	var positions: Array = _elements.keys()
	for pos: Variant in positions:
		var element: ElementData = _elements.get(pos) as ElementData
		if element:
			EventBus.element_removed.emit(pos, element.element_type.element_id)
	_elements.clear()
