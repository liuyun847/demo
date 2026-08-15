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
## 源建筑位置注册表: {Vector2i: true}
## 仅记录源头建筑的位置，元素类型从 SourceNode 节点实时读取（用户可能通过面板修改）
var _source_buildings: Dictionary = {}
var building_manager_ref: BuildingManager = null
## is_building_at 在 ref 未初始化时只 warning 一次的标记
var _warned_null_building_ref: bool = false

## 脏区域跟踪: {Vector2i: true}
## 记录自上次扩散/反应扫描以来发生过变化的格子（含邻接格），
## 供增量扩散跳过稳定区域（方向 A：脏区域增量更新，稳定水体不重复重算）
var _dirty_cells: Dictionary = {}


## 注册源头建筑位置（由 ReactionCoordinator 在建筑放置时调用）
func register_source_building(pos: Vector2i) -> void:
	_source_buildings[pos] = true
	_mark_dirty(pos)


## 取消注册源头建筑位置（由 ReactionCoordinator 在建筑移除时调用，erase 安全）
func unregister_source_building(pos: Vector2i) -> void:
	_source_buildings.erase(pos)
	_mark_dirty(pos)


## 获取所有源头建筑位置字典（key=Vector2i, value=true）
func get_source_buildings() -> Dictionary:
	return _source_buildings

## 在指定位置放置元素
func set_element(pos: Vector2i, element_id: String, source_y_val: int) -> bool:
	if _elements.has(pos):
		return false
	if is_building_at(pos):
		return false
	_elements[pos] = element_id
	_source_y[pos] = source_y_val
	_mark_dirty(pos)
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
	_mark_dirty(pos)
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
	# 记录 from 的水源标记和产物计时器，迁移到 to
	var was_source: bool = _source_positions.has(from)
	var product_timer: Variant = _product_timers.get(from, null)
	_elements.erase(from)
	_source_y.erase(from)
	_source_positions.erase(from)
	_product_timers.erase(from)
	_elements[to] = element_id
	_source_y[to] = sy
	if was_source:
		_source_positions[to] = true
	if product_timer != null:
		_product_timers[to] = product_timer
	_mark_dirty(from)
	_mark_dirty(to)
	# 用单信号替代 removed+spawned 两次发射（滑动密集场景下显著省信号开销）
	EventBus.element_moved.emit(from, to, element_id)
	return true

## 标记为水源
func mark_as_source(pos: Vector2i) -> void:
	if not _source_positions.has(pos):
		_source_positions[pos] = true
		# 水源状态变化影响其所在区域的有源判定（has_source/rate），需纳入重算
		_mark_dirty(pos)

## 检查是否为水源
func is_source_pos(pos: Vector2i) -> bool:
	return _source_positions.has(pos)

## 取消水源标记
func unmark_source(pos: Vector2i) -> void:
	if _source_positions.erase(pos):
		_mark_dirty(pos)

## 清除所有水源标记
## 被清除的水源格子会影响其所在区域的有源判定（源头切换/移除后旧体失去水源），
## 因此对每个原水源格标记脏区域；无水源时为零开销。
func clear_all_sources() -> void:
	for pos: Vector2i in _source_positions.keys():
		_mark_dirty(pos)
	_source_positions.clear()

## 标记位置为反应产物，存活 ticks 个 tick
func mark_as_product(pos: Vector2i, ticks: int) -> void:
	_product_timers[pos] = ticks

## 检查位置是否有活跃的产物存续标记
func is_product(pos: Vector2i) -> bool:
	return _product_timers.has(pos)

## 递减所有产物计时器，移除过期的
func tick_products() -> void:
	var expired: Array[Vector2i] = []
	for pos: Vector2i in _product_timers:
		_product_timers[pos] -= 1
		if _product_timers[pos] <= 0:
			expired.append(pos)
	for pos: Vector2i in expired:
		_product_timers.erase(pos)

## 检查位置是否可用（无元素、无建筑）
func is_position_available(pos: Vector2i) -> bool:
	return not _elements.has(pos) and not is_building_at(pos)

## 检查位置是否有建筑
func is_building_at(pos: Vector2i) -> bool:
	if building_manager_ref == null:
		# 未初始化时视为有建筑，阻止元素放置，避免元素错误地占据建筑格子
		# 仅首次 warning，防止高频调用刷屏
		if not _warned_null_building_ref:
			push_warning("ElementGrid: building_manager_ref 未初始化，is_building_at 返回 true 阻止放置")
			_warned_null_building_ref = true
		return true
	return building_manager_ref.get_building_node(pos) != null

## 获取所有有元素的格子位置
func get_all_element_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for key: Vector2i in _elements:
		positions.append(key)
	return positions

## 获取完整的元素字典副本
func get_all_elements() -> Dictionary:
	return _elements.duplicate()

## 清空所有元素数据
func clear_all() -> void:
	var positions: Array[Vector2i] = []
	positions.assign(_elements.keys())
	for pos: Vector2i in positions:
		var element_id: String = _elements[pos]
		EventBus.element_removed.emit(pos, element_id)
	_elements.clear()
	_source_y.clear()
	_source_positions.clear()
	_product_timers.clear()
	_source_buildings.clear()
	_dirty_cells.clear()


# ========== 脏区域跟踪（方向 A：增量更新） ==========

## 标记 pos 及其四邻为脏区域。
## 位置变化会同时影响邻格的可达性（流动/扩张/反应判定），因此邻格也需重算。
func _mark_dirty(pos: Vector2i) -> void:
	_dirty_cells[pos] = true
	for dir: Vector2i in GridCoordinate.DIR_4:
		_dirty_cells[pos + dir] = true

## 取走全部脏区域位置并清空（增量扩散/反应扫描的输入）
func take_dirty() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.assign(_dirty_cells.keys())
	_dirty_cells.clear()
	return positions

## 查看当前脏区域位置（副本，不消费；用于反应扫描同时保留给下一 tick 扩散重算）
func peek_dirty() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.assign(_dirty_cells.keys())
	return positions

## 当前待处理脏区域数量
func get_dirty_count() -> int:
	return _dirty_cells.size()

## 标记所有现有元素为脏（建筑放置/移除等全局变更时使用，事件低频可接受全量）
func mark_all_dirty() -> void:
	for pos: Vector2i in _elements:
		_mark_dirty(pos)
