class_name ElementGrid
extends Node

## 元素格子数据: {Vector2i: String(element_id)}
var _elements: Dictionary = {}
## 元素格子的源Y坐标: {Vector2i: int}
var _source_y: Dictionary = {}
## 水源标记: {Vector2i: true}
var _source_positions: Dictionary = {}
## 反应产物存续计时器: {Vector2i: int(剩余 tick 数)}
var _product_timers: Dictionary = {}
var building_manager_ref: BuildingManager = null

## 在指定位置放置元素
func set_element(pos: Vector2i, element_id: String, source_y_val: int) -> bool:
	if _elements.has(pos):
		return false
	if is_building_at(pos):
		return false
	_elements[pos] = element_id
	_source_y[pos] = source_y_val
	EventBus.element_spawned.emit(pos, element_id)
	return true

## 移除指定位置的元素
func remove_element(pos: Vector2i) -> void:
	if not _elements.has(pos):
		return
	var element_id: String = _elements[pos]
	_elements.erase(pos)
	_source_y.erase(pos)
	_source_positions.erase(pos)
	_product_timers.erase(pos)
	EventBus.element_removed.emit(pos, element_id)

## 检查指定位置是否有元素
func has_element(pos: Vector2i) -> bool:
	return _elements.has(pos)

## 获取指定位置的元素ID，无元素时返回空字符串
func get_element_id(pos: Vector2i) -> String:
	return _elements.get(pos, "")

## 获取指定位置的源Y坐标
func get_source_y(pos: Vector2i) -> int:
	return _source_y.get(pos, 0)

## 将元素从 from 移动到 to
func move_element(from: Vector2i, to: Vector2i) -> bool:
	if not _elements.has(from):
		return false
	if _elements.has(to):
		return false
	if is_building_at(to):
		return false
	var element_id: String = _elements[from]
	var sy: int = _source_y.get(from, 0)
	_elements.erase(from)
	_source_y.erase(from)
	_source_positions.erase(from)
	_product_timers.erase(from)
	_elements[to] = element_id
	_source_y[to] = sy
	EventBus.element_removed.emit(from, element_id)
	EventBus.element_spawned.emit(to, element_id)
	return true

## 标记为水源
func mark_as_source(pos: Vector2i) -> void:
	_source_positions[pos] = true

## 检查是否为水源
func is_source_pos(pos: Vector2i) -> bool:
	return _source_positions.has(pos)

## 取消水源标记
func unmark_source(pos: Vector2i) -> void:
	_source_positions.erase(pos)

## 清除所有水源标记
func clear_all_sources() -> void:
	_source_positions.clear()

## 标记位置为反应产物，存活 ticks 个 tick
func mark_as_product(pos: Vector2i, ticks: int) -> void:
	_product_timers[pos] = ticks

## 检查位置是否有活跃的产物存续标记
func is_product(pos: Vector2i) -> bool:
	return _product_timers.has(pos)

## 递减所有产物计时器，移除过期的
func tick_products() -> void:
	var expired: Array = []
	for pos: Variant in _product_timers:
		_product_timers[pos] -= 1
		if _product_timers[pos] <= 0:
			expired.append(pos)
	for pos: Variant in expired:
		_product_timers.erase(pos)

## 检查位置是否可用（无元素、无建筑）
func is_position_available(pos: Vector2i) -> bool:
	return not _elements.has(pos) and not is_building_at(pos)

## 检查位置是否有建筑
func is_building_at(pos: Vector2i) -> bool:
	if building_manager_ref == null:
		return false
	return building_manager_ref.get_building_node(pos) != null

## 获取所有有元素的格子位置
func get_all_element_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for key: Variant in _elements:
		positions.append(key as Vector2i)
	return positions

## 获取完整的元素字典副本
func get_all_elements() -> Dictionary:
	return _elements.duplicate()

## 清空所有元素数据
func clear_all() -> void:
	var positions: Array = _elements.keys()
	for pos: Variant in positions:
		var element_id: String = _elements[pos]
		EventBus.element_removed.emit(pos, element_id)
	_elements.clear()
	_source_y.clear()
	_source_positions.clear()
	_product_timers.clear()
