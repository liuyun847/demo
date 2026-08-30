class_name BuildingManager
extends Node2D

## 建筑管理器：建筑数据结构 + 节点生命周期 + 物品流系统装配。
## 建筑占一格；朝向/配置存于 BuildingData（direction/op_choice/splitter_phase/splitter_filters），
## 节点仅负责视觉与交互；模拟由 ItemFlowCoordinator 驱动（数据驱动，不依赖节点）。

var buildings: Dictionary[Vector2i, BuildingData] = {} # key: Vector2i, value: BuildingData
var _building_nodes: Dictionary[Vector2i, Node2D] = {} # key: Vector2i, value: Node2D
## 传送带连接信息缓存（BeltConnection.compute 结果，供带子/机器节点绘制连接视觉）。
## 在任何建筑增删/清空后刷新（节点 _draw 经 get_parent() 读取）。
var belt_connections: Dictionary = {}

## 源质服务（依赖注入），未注入时回退到全局 EssencePool
var _essence_service: Variant = null

var item_renderer: ItemRenderer = null

const _GridUtils: GDScript = preload("res://scripts/grid/grid_utils.gd")
const _BuildingFactory: GDScript = preload("res://scripts/building/building_factory.gd")

func _ready() -> void:
	_init_flow_systems()
	# 机器配置面板变更 → 立即同步节点状态到 data，模拟器下一 tick 即读新配置
	# （不依赖 SaveManager 延迟保存的链路）
	EventBus.machine_config_changed.connect(_on_machine_config_changed)

func _exit_tree() -> void:
	if EventBus.machine_config_changed.is_connected(_on_machine_config_changed):
		EventBus.machine_config_changed.disconnect(_on_machine_config_changed)

func _on_machine_config_changed(grid_pos: Vector2i) -> void:
	var data := get_building_data(grid_pos)
	var node := get_building_node(grid_pos)
	if data != null and node != null:
		BuildingDataSyncService.sync_from_node(data, node)

func _init_flow_systems() -> void:
	# 物品流协调器（分帧模拟）
	var coordinator := ItemFlowCoordinator.new()
	coordinator.name = "ItemFlowCoordinator"
	coordinator.init(self)
	add_child(coordinator)
	# 物品渲染器（消费协调器事件，做位置插值）
	var renderer := ItemRenderer.new()
	renderer.name = "ItemRenderer"
	renderer.setup(coordinator.grid)
	add_child(renderer)
	item_renderer = renderer

func get_flow_coordinator() -> ItemFlowCoordinator:
	return get_node_or_null("ItemFlowCoordinator") as ItemFlowCoordinator

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

## 注入源质服务（用于测试解耦）
func set_essence_service(service: Variant) -> void:
	_essence_service = service

## 获取源质服务，未注入时回退到全局 EssencePool
func _get_essence() -> Variant:
	if _essence_service == null:
		return EssencePool
	return _essence_service

func place_building(grid_pos: Vector2i, building_type: String = "default", restore_data: Dictionary = {}) -> bool:
	var existing: BuildingData = get_building_data(grid_pos)
	if existing != null:
		# 分流器可放在传送带上：该格转换为"传送带+分流器"一体建筑（带子一并归属建筑）
		if _can_convert_to_belt_splitter(existing, building_type):
			return _place_belt_splitter_on_belt(grid_pos, existing, building_type, restore_data)
		return false

	# 源质消耗（当前纯搭建阶段全部免费；cost 表为空不再扣费）
	var cost: float = GameConfig.BUILDING_ESSENCE_COSTS.get(building_type, 0.0)
	if cost > 0.0 and restore_data.is_empty():
		var es: Variant = _get_essence()
		if not es.has(cost):
			return false
		es.subtract(cost)

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	var node_name: String = _GridUtils.get_building_node_name(grid_pos)
	var world_pos: Vector2 = GridCoordinate.grid_to_world(grid_pos)

	var building_node: Node2D = _BuildingFactory.create_building(building_type, grid_pos, world_pos, node_name)
	add_child(building_node)

	BuildingDataSyncService.sync_from_node(data, building_node, restore_data)

	_building_nodes[grid_pos] = building_node
	buildings[grid_pos] = data
	_refresh_belt_connections()
	EventBus.building_placed.emit(grid_pos)
	return true

## 刷新传送带连接缓存（建筑变更后调用，供视觉节点读取）
func _refresh_belt_connections() -> void:
	belt_connections = BeltConnection.compute(buildings)
	for node: Node2D in _building_nodes.values():
		node.queue_redraw()

## 可否放置到指定格：空格恒可；占用格仅当为传送带且类型可转换为一体建筑（分流器）
## 时方可（放置即"替换"为传送带+分流器一体建筑）。供输入/粘贴流程复用同一规则。
func can_place(grid_pos: Vector2i, building_type: String) -> bool:
	var existing: BuildingData = get_building_data(grid_pos)
	if existing == null:
		return true
	return _can_convert_to_belt_splitter(existing, building_type)

## 类型是否为"可放传送带上"的转换类型（分流器本体或一体建筑本身）
static func _is_belt_splitter_convert_type(building_type: String) -> bool:
	return building_type == MachineSpec.T_SPLITTER or building_type == MachineSpec.T_BELT_SPLITTER

static func _can_convert_to_belt_splitter(existing: BuildingData, building_type: String) -> bool:
	return existing != null \
		and MachineSpec.is_belt(existing.building_type) \
		and _is_belt_splitter_convert_type(building_type)

## 在传送带格上放置分流器：替换为"传送带+分流器"一体建筑。
## 方向取 restore_data.direction（拖拽/R 键放置朝向），缺省沿用原带方向；
## 其余状态（splitter_phase 等）经同步服务恢复。原带节点移除（物品保留在格上，
## 由一体建筑下一 tick 处理）。
func _place_belt_splitter_on_belt(grid_pos: Vector2i, existing: BuildingData, building_type: String, restore_data: Dictionary) -> bool:
	# 源质消耗与正常放置一致（纯搭建阶段免费）
	var cost: float = GameConfig.BUILDING_ESSENCE_COSTS.get(building_type, 0.0)
	if cost > 0.0 and restore_data.is_empty():
		var es: Variant = _get_essence()
		if not es.has(cost):
			return false
		es.subtract(cost)

	var old_node := get_building_node(grid_pos)
	if old_node != null:
		old_node.queue_free()

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = MachineSpec.T_BELT_SPLITTER
	data.direction = int(restore_data.get("direction", existing.direction))

	var node_name: String = _GridUtils.get_building_node_name(grid_pos)
	var world_pos: Vector2 = GridCoordinate.grid_to_world(grid_pos)
	var building_node: Node2D = _BuildingFactory.create_building(
		MachineSpec.T_BELT_SPLITTER, grid_pos, world_pos, node_name)
	add_child(building_node)

	# 强制把已确定的方向写入节点+数据（restore 为空时同步服务会反向用节点默认方向覆盖）
	var effective_restore := restore_data.duplicate()
	effective_restore["direction"] = data.direction
	BuildingDataSyncService.sync_from_node(data, building_node, effective_restore)

	_building_nodes[grid_pos] = building_node
	buildings[grid_pos] = data
	_refresh_belt_connections()
	EventBus.building_placed.emit(grid_pos)
	return true

func remove_building(grid_pos: Vector2i) -> bool:
	if not has_building(grid_pos):
		return false

	var node := get_building_node(grid_pos)
	if node == null:
		return false
	node.queue_free()

	# 删除建筑前收集其端口布局（用于清理建筑占用格/端口格上的残留物品）
	var data := get_building_data(grid_pos)
	_building_nodes.erase(grid_pos)
	buildings.erase(grid_pos)
	_clear_items_on_gone_building(grid_pos, data)
	_refresh_belt_connections()
	EventBus.building_removed.emit(grid_pos)
	return true

## 建筑删除后清理残留物品：建筑原格 + 机器输入/输出端口格上不再被支撑的物品
## 一律移除（含 despawn 事件，渲染层同步消失），保证数字不遗留在空地上。
## 保留条件用 ItemSimulator 的"可停靠格"判定：若该格仍是另一台现存机器/传送带的
## 停靠格（如端口重叠），物品保留继续流通，避免误删（物品永不丢失原则）。
## 另清理"面槽"物品：被删机器作为生产者时其面物品就地清除；面物品的消费机器
## 已被删除/不再对齐时同样清除（否则永久卡在无消费方的共享边上）。
func _clear_items_on_gone_building(grid_pos: Vector2i, data: BuildingData) -> void:
	var coordinator := get_flow_coordinator()
	if coordinator == null or coordinator.grid == null:
		return
	var grid := coordinator.grid
	var affected_cells: Array[Vector2i] = [grid_pos]
	if data != null and MachineSpec.is_machine(data.building_type):
		for off: Vector2i in MachineSpec.get_ins(data.building_type, data.direction):
			affected_cells.append(grid_pos + off)
		for off: Vector2i in MachineSpec.get_outs(data.building_type, data.direction):
			affected_cells.append(grid_pos + off)
	var dock_cells := ItemSimulator.collect_dock_cells(buildings)
	var events: Array[Dictionary] = []
	for pos: Vector2i in affected_cells:
		if dock_cells.has(pos):
			continue
		var item: Item = grid.take_item(pos)
		if item != null:
			events.append({"kind": "despawn", "at": pos, "item": item})
	events.append_array(_sweep_invalid_edge_items(grid))
	if not events.is_empty():
		EventBus.sim_tick_completed.emit(events)

## 扫描面槽：无有效来源/消费方（生产机器已删除，或贴面对齐目标已不存在/失配）
## 的面物品一律清除。
func _sweep_invalid_edge_items(grid: ItemGrid) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for producer_cell: Vector2i in grid.edge_slots.keys():
		var slot: Dictionary = grid.get_edge(producer_cell)
		if slot.is_empty():
			continue
		# 生产者校验：面物品的来源机器必须仍然存在（一体建筑也可作为生产者）
		var producer: BuildingData = buildings.get(producer_cell) as BuildingData
		if producer == null or not MachineSpec.is_machine(producer.building_type):
			_clear_edge_slot(grid, producer_cell, slot, events)
			continue
		# 消费方校验：贴面对齐目标必须仍存在且互认（有输入口正对本生产者）
		var target: Vector2i = producer_cell + slot["front"]
		var target_data: BuildingData = buildings.get(target) as BuildingData
		var aligned := target_data != null \
			and MachineSpec.is_machine(target_data.building_type) \
			and not MachineSpec.is_belt_splitter(target_data.building_type) \
			and MachineSpec.get_ins(target_data.building_type, target_data.direction).has(producer_cell - target)
		if not aligned:
			_clear_edge_slot(grid, producer_cell, slot, events)
	return events

func _clear_edge_slot(grid: ItemGrid, producer_cell: Vector2i, slot: Dictionary, events: Array[Dictionary]) -> void:
	var item: Item = grid.take_edge(producer_cell)
	if item != null:
		events.append({"kind": "despawn", "at": producer_cell, "face": slot["front"], "item": item})

func get_all_building_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.assign(buildings.keys())
	return positions

func get_all_buildings_data() -> Dictionary:
	var copy: Dictionary = {}
	for grid_pos: Vector2i in buildings.keys():
		copy[grid_pos] = buildings[grid_pos].clone()
	return copy

func clear_all_buildings() -> void:
	# 先收集所有建筑位置，用于清除后逐个触发信号
	var all_positions: Array[Vector2i] = []
	all_positions.assign(buildings.keys())
	clear_all_buildings_silent()
	for grid_pos: Vector2i in all_positions:
		EventBus.building_removed.emit(grid_pos)

## 静默清除所有建筑，不触发事件
func clear_all_buildings_silent() -> void:
	for node: Node2D in _building_nodes.values():
		node.queue_free()
	_building_nodes.clear()
	buildings.clear()
	_refresh_belt_connections()
	var coordinator := get_node_or_null("ItemFlowCoordinator") as ItemFlowCoordinator
	if coordinator:
		coordinator.clear_all()
	if item_renderer:
		item_renderer.clear_all()

func get_buildings_in_cells(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for grid_pos: Vector2i in cells:
		if has_building(grid_pos):
			var data: BuildingData = buildings[grid_pos]
			result[grid_pos] = data.building_type
	return result

func get_building_type(grid_pos: Vector2i) -> String:
	if buildings.has(grid_pos):
		return buildings[grid_pos].building_type
	return ""

func get_building_data(grid_pos: Vector2i) -> BuildingData:
	return buildings.get(grid_pos) as BuildingData

func get_building_node(grid_pos: Vector2i) -> Node:
	return _building_nodes.get(grid_pos) as Node

func place_buildings_in_line(cells: Array[Vector2i], building_type: String = "default", restore_data: Dictionary = {}) -> int:
	var placed_count := 0
	for grid_pos: Vector2i in cells:
		if place_building(grid_pos, building_type, restore_data):
			placed_count += 1
	return placed_count

func remove_buildings_in_rect(cells: Array[Vector2i]) -> int:
	var removed_count := 0
	for grid_pos: Vector2i in cells:
		if remove_building(grid_pos):
			removed_count += 1
	return removed_count