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
func process_all() -> void:
	var all_positions: Array[Vector2i] = _grid.get_all_element_positions()
	if all_positions.is_empty():
		return

	# 快照当前元素状态，避免迭代中修改数据
	var snapshot: Dictionary = _grid.get_all_elements()
	# 已参与反应的格子集合，避免一帧内多次反应
	var reacted: Dictionary = {}

	var pending_reactions: Array[Dictionary] = []

	for pos: Vector2i in all_positions:
		if reacted.has(pos):
			continue
		var element_id: String = snapshot.get(pos, "")
		if element_id.is_empty():
			continue

		var type_data: ElementTypeData = ElementRegistry.get_element_type(element_id)
		if type_data == null or not type_data.reactive:
			continue

		for dir: Vector2i in NEIGHBORS:
			var neighbor_pos: Vector2i = pos + dir
			if reacted.has(neighbor_pos):
				continue
			var neighbor_id: String = snapshot.get(neighbor_pos, "")
			if neighbor_id.is_empty():
				continue

			var neighbor_type: ElementTypeData = ElementRegistry.get_element_type(neighbor_id)
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

	# 执行所有待处理的反应
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
