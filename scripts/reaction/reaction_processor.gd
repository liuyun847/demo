class_name ReactionProcessor
extends RefCounted

## 4 方向邻居偏移
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

var _registry: ReactionRegistry
var _grid: ElementGrid
## 源质服务（依赖注入），未注入时回退到全局 EssencePool
var _essence_service: Variant = null

func _init(registry: ReactionRegistry, grid: ElementGrid, essence_service: Variant = null) -> void:
	_registry = registry
	_grid = grid
	_essence_service = essence_service

## 获取源质服务，未注入时回退到全局 EssencePool
func _get_essence() -> Variant:
	if _essence_service == null:
		return EssencePool
	return _essence_service

## 处理所有相邻格子的反应
## dirty_positions: 可选，脏区域位置集合。
##   - null（默认）: 全量扫描所有元素（向后兼容，测试用）
##   - Array[Vector2i]: 增量模式，仅扫描脏区域及其邻格（方向 A）。
##     未变化区域中的相邻对要么已反应过、要么被永久阻断（无变化），无需重复扫描。
func process_all(dirty_positions: Variant = null) -> void:
	if dirty_positions == null:
		_process_all_full()
		return
	if dirty_positions.is_empty():
		return
	_process_all_dirty(dirty_positions)


## 全量模式：快照所有元素并扫描全部位置（兼容旧调用/测试）
func _process_all_full() -> void:
	var all_positions: Array[Vector2i] = _grid.get_all_element_positions()
	if all_positions.is_empty():
		return

	# 快照当前元素状态，避免迭代中修改数据。
	# 基准实测：本地 Dictionary.get 内置调用比每格走 GDScript 方法分派更快，
	# 一次性 duplicate 成本(<0.3ms)远低于 2N 次 get_element_id 方法调用开销
	var snapshot: Dictionary = _grid.get_all_elements()
	# 已参与反应的格子集合，避免一帧内多次反应
	var reacted: Dictionary = {}

	var pending_reactions: Array[Dictionary] = _scan_reactions(snapshot, all_positions, reacted)

	_execute_reactions(pending_reactions)


## 增量模式：仅扫描脏区域位置（方向 A）
## 脏区域由 ElementGrid 在元素变更时记录（含四邻），因此覆盖所有可能产生新反应的相邻对。
func _process_all_dirty(dirty_positions: Array[Vector2i]) -> void:
	var reacted: Dictionary = {}

	var pending_reactions: Array[Dictionary] = _scan_reactions(null, dirty_positions, reacted)

	_execute_reactions(pending_reactions)


## 扫描给定位置集合，收集待执行的反应。
## snapshot 为 null 时直接从 grid 读取（增量模式，扫描期间无修改）。
func _scan_reactions(snapshot: Variant, positions: Array[Vector2i], reacted: Dictionary) -> Array[Dictionary]:
	var pending_reactions: Array[Dictionary] = []

	# 类型注册表查询缓存：元素类型只有少数几种，逐格重复查 registry 是冗余开销。
	# 本地字典缓存后，海量元素仅首次查询走方法分派
	var type_cache: Dictionary = {}

	for pos: Vector2i in positions:
		if reacted.has(pos):
			continue
		var element_id: String = _read_id(snapshot, pos)
		if element_id.is_empty():
			continue

		var type_data: ElementTypeData = _cached_type(type_cache, element_id)
		if type_data == null or not type_data.reactive:
			continue

		for dir: Vector2i in NEIGHBORS:
			var neighbor_pos: Vector2i = pos + dir
			if reacted.has(neighbor_pos):
				continue
			var neighbor_id: String = _read_id(snapshot, neighbor_pos)
			if neighbor_id.is_empty():
				continue

			var neighbor_type: ElementTypeData = _cached_type(type_cache, neighbor_id)
			if neighbor_type == null or not neighbor_type.reactive:
				continue

			var rule: Dictionary = _registry.find_reaction(element_id, neighbor_id)
			if rule.is_empty():
				continue

			# 确定产物位置：密度大的元素所在格子
			var product_pos: Vector2i
			if type_data.density >= neighbor_type.density:
				product_pos = pos
			else:
				product_pos = neighbor_pos

			# 产物位被建筑占据则跳过（reactant 会在执行时先移除，所以元素不挡路）
			if _grid.is_building_at(product_pos):
				continue

			pending_reactions.append({
				"pos_a": pos,
				"pos_b": neighbor_pos,
				"product": rule["product"],
				"product_pos": product_pos,
				"byproduct_essence": rule["byproduct_essence"],
			})
			reacted[pos] = true
			reacted[neighbor_pos] = true
			break  # 每个格子每帧最多参与一次反应

	return pending_reactions


## 读取位置元素 ID：快照模式走本地字典，增量模式直接查 grid
func _read_id(snapshot: Variant, pos: Vector2i) -> String:
	if snapshot == null:
		return _grid.get_element_id(pos)
	return snapshot.get(pos, "")


## 类型查询缓存
func _cached_type(type_cache: Dictionary, element_id: String) -> ElementTypeData:
	var type_data: ElementTypeData = type_cache.get(element_id)
	if type_data == null:
		type_data = ElementRegistry.get_element_type(element_id)
		type_cache[element_id] = type_data
	return type_data


## 执行所有待处理的反应
func _execute_reactions(pending_reactions: Array[Dictionary]) -> void:
	for reaction: Dictionary in pending_reactions:
		var pos_a: Vector2i = reaction["pos_a"]
		var pos_b: Vector2i = reaction["pos_b"]
		var product_pos: Vector2i = reaction["product_pos"]
		var product_id: String = reaction["product"]
		var byproduct_essence: float = reaction["byproduct_essence"]

		# 验证两个 reactant 仍存在
		if not _grid.has_element(pos_a) or not _grid.has_element(pos_b):
			continue

		# 移除两个 reactant
		_grid.remove_element(pos_a)
		_grid.remove_element(pos_b)

		# 放置产物（此时两个 reactant 已移除，product_pos 必然空闲）
		if not _grid.set_element(product_pos, product_id, product_pos.y):
			# 防御性处理：极端边界（不应发生），跳过标记产物和源质，但不回滚
			push_error("ReactionProcessor: 产物放置失败 pos=%s product=%s" % [str(product_pos), product_id])
			continue

		# 标记产物存续，防止下一 tick 扩散时立即收缩消失
		_grid.mark_as_product(product_pos, GameConfig.PRODUCT_SURVIVAL_TICKS)

		# 产生副产物源质
		if byproduct_essence > 0.0:
			_get_essence().add(byproduct_essence)
