class_name ElementGrid
extends Node

var _fluid: Dictionary = {}
var _source_y: Dictionary = {}
var _source_positions: Dictionary = {}
var building_manager_ref: BuildingManager = null

func set_fluid(pos: Vector2i, source_y_val: int) -> bool:
	if _fluid.has(pos):
		return false
	if is_building_at(pos):
		return false
	_fluid[pos] = true
	_source_y[pos] = source_y_val
	EventBus.element_spawned.emit(pos, "water")
	return true

func remove_fluid(pos: Vector2i) -> void:
	if not _fluid.has(pos):
		return
	_fluid.erase(pos)
	_source_y.erase(pos)
	_source_positions.erase(pos)
	EventBus.element_removed.emit(pos, "water")

func has_fluid(pos: Vector2i) -> bool:
	return _fluid.has(pos)

func get_source_y(pos: Vector2i) -> int:
	return _source_y.get(pos, 0)

func move_fluid(from: Vector2i, to: Vector2i) -> bool:
	if not _fluid.has(from):
		return false
	if _fluid.has(to):
		return false
	if is_building_at(to):
		return false
	var sy: int = _source_y.get(from, 0)
	_fluid.erase(from)
	_source_y.erase(from)
	_source_positions.erase(from)
	_fluid[to] = true
	_source_y[to] = sy
	EventBus.element_removed.emit(from, "water")
	EventBus.element_spawned.emit(to, "water")
	return true

func mark_as_source(pos: Vector2i) -> void:
	_source_positions[pos] = true

func is_source_pos(pos: Vector2i) -> bool:
	return _source_positions.has(pos)

func unmark_source(pos: Vector2i) -> void:
	_source_positions.erase(pos)

func clear_all_sources() -> void:
	_source_positions.clear()

func is_position_available(pos: Vector2i) -> bool:
	return not _fluid.has(pos) and not is_building_at(pos)

func is_building_at(pos: Vector2i) -> bool:
	if building_manager_ref == null:
		return false
	return building_manager_ref.get_building_node(pos) != null

func get_all_fluid_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for key: Variant in _fluid:
		positions.append(key as Vector2i)
	return positions

func clear_all() -> void:
	var positions: Array = _fluid.keys()
	for pos: Variant in positions:
		EventBus.element_removed.emit(pos, "water")
	_fluid.clear()
	_source_y.clear()
	_source_positions.clear()
