class_name BuildingManager
extends Node2D

var buildings: Dictionary[Vector2i, BuildingData] = {} # key: Vector2i, value: BuildingData
var _building_nodes: Dictionary[Vector2i, Node2D] = {} # key: Vector2i, value: Node2D
var network_pipes: Array[PipeNode] = []

const _GridUtils: GDScript = preload("res://scripts/grid/grid_utils.gd")
const _BuildingFactory: GDScript = preload("res://scripts/building/building_factory.gd")

@onready var pipe_render: PipeRenderSystem = $PipeRenderSystem

var element_renderer: Node2D = null

func _ready() -> void:
	_init_element_renderer()
	_init_reaction_coordinator()

func _init_element_renderer() -> void:
	var ElementRendererScript: GDScript = load("res://scripts/reaction/element_renderer.gd")
	if ElementRendererScript == null:
		return
	var renderer: Node2D = ElementRendererScript.new() as Node2D
	if renderer == null:
		return
	renderer.name = "ElementRenderer"
	element_renderer = renderer
	add_child(renderer)

func _init_reaction_coordinator() -> void:
	var ReactionCoordinatorScript: GDScript = load("res://scripts/reaction/reaction_coordinator.gd")
	if ReactionCoordinatorScript == null:
		return
	var coordinator: ReactionCoordinator = ReactionCoordinatorScript.new()
	if coordinator == null:
		return
	coordinator.name = "ReactionCoordinator"
	coordinator.init(self )
	add_child(coordinator)

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func place_building(grid_pos: Vector2i, building_type: String = "default", restore_data: Dictionary = {}) -> bool:
	if has_building(grid_pos):
		return false

	var cost: float = GameConfig.building_essence_costs.get(building_type, 0.0)
	if cost > 0.0 and restore_data.is_empty():
		if not EssencePool.has(cost):
			return false
		EssencePool.subtract(cost)

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	var node_name: String = _GridUtils.get_building_node_name(grid_pos)
	var world_pos: Vector2 = GridCoordinate.grid_to_world(grid_pos)

	var building_node: Node2D = _BuildingFactory.create_building(building_type, grid_pos, world_pos, node_name)
	add_child(building_node)

	BuildingData.sync_capacity_from_node(data, building_node, restore_data)
	BuildingData.sync_emitter_type_from_node(data, building_node, restore_data)

	_building_nodes[grid_pos] = building_node
	if building_node is PipeNode:
		_register_pipe(building_node)
		network_pipes.append(building_node)
	buildings[grid_pos] = data
	EventBus.building_placed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
	return true

func remove_building(grid_pos: Vector2i) -> bool:
	if not has_building(grid_pos):
		return false

	var node := get_building_node(grid_pos)
	if node == null:
		return false
	if BuildingData.is_container_building(node):
		var data: BuildingData = buildings[grid_pos]
		BuildingData.sync_capacity_from_node(data, node)
	if node is EmitterNode:
		var data: BuildingData = buildings[grid_pos]
		BuildingData.sync_emitter_type_from_node(data, node)
	node.queue_free()

	var node_to_remove: Node2D = _building_nodes.get(grid_pos) as Node2D
	if node_to_remove is PipeNode:
		_unregister_pipe(node_to_remove)
		network_pipes.erase(node_to_remove)
	_building_nodes.erase(grid_pos)
	buildings.erase(grid_pos)
	EventBus.building_removed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
	return true

func get_all_building_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.assign(buildings.keys())
	return positions

func get_all_buildings_data() -> Dictionary:
	var copy: Dictionary = {}
	for grid_pos: Vector2i in buildings.keys():
		var data: BuildingData = buildings[grid_pos]
		var new_data := BuildingData.new()
		new_data.grid_position = data.grid_position
		new_data.building_type = data.building_type
		new_data.capacity = data.capacity
		new_data.max_capacity = data.max_capacity
		new_data.element_type_id = data.element_type_id
		new_data.output_direction = data.output_direction
		copy[grid_pos] = new_data
	return copy

func clear_all_buildings() -> void:
	for grid_pos: Vector2i in buildings.keys():
		remove_building(grid_pos)

## 静默清除所有建筑，不触发事件也不刷新管道。
## 与 clear_all_buildings() 不同，此方法不发送 building_placed/building_removed 信号。
func clear_all_buildings_silent() -> void:
	for node: Node2D in _building_nodes.values():
		node.queue_free()
	_building_nodes.clear()
	buildings.clear()
	network_pipes.clear()
	if pipe_render:
		pipe_render.clear_all()
	if element_renderer:
		element_renderer.clear_all()
	var coordinator := get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if coordinator:
		coordinator.mark_dirty()

func get_buildings_in_cells(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for grid_pos: Vector2i in cells:
		if has_building(grid_pos):
			var data: BuildingData = buildings[grid_pos]
			result[grid_pos] = data.building_type
	return result

func _register_pipe(pipe: PipeNode) -> void:
	if pipe_render:
		pipe_render.register_pipe(pipe)


func _unregister_pipe(pipe: PipeNode) -> void:
	if pipe_render:
		pipe_render.unregister_pipe(pipe)


func get_building_type(grid_pos: Vector2i) -> String:
	if buildings.has(grid_pos):
		return buildings[grid_pos].building_type
	return ""

func get_building_data(grid_pos: Vector2i) -> BuildingData:
	return buildings.get(grid_pos) as BuildingData

func get_building_node(grid_pos: Vector2i) -> Node:
	return _building_nodes.get(grid_pos) as Node

func is_pipe_or_buffer_at(grid_pos: Vector2i) -> bool:
	if not buildings.has(grid_pos):
		return false
	var data: BuildingData = buildings[grid_pos] as BuildingData
	if data == null:
		return false
	return BuildingData.is_pipe_or_buffer(data.building_type) or \
		BuildingData.is_emitter(data.building_type) or \
		BuildingData.is_collector(data.building_type)

func place_buildings_in_line(cells: Array[Vector2i], building_type: String = "default") -> int:
	var placed_count := 0
	for grid_pos: Vector2i in cells:
		if place_building(grid_pos, building_type):
			placed_count += 1
	return placed_count

func remove_buildings_in_rect(cells: Array[Vector2i]) -> int:
	var removed_count := 0
	for grid_pos: Vector2i in cells:
		if remove_building(grid_pos):
			removed_count += 1
	return removed_count

func _refresh_pipe_connections(grid_pos: Vector2i) -> void:
	for offset: Vector2i in GridCoordinate.DIR_4:
		var npos: Vector2i = grid_pos + offset
		if has_building(npos):
			var node := get_building_node(npos)
			if node is PipeNode:
				node.refresh_connections(is_pipe_or_buffer_at)

	var self_node := get_building_node(grid_pos)
	if self_node is PipeNode:
		self_node.refresh_connections(is_pipe_or_buffer_at)
