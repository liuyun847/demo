class_name BuildingManager
extends Node2D

var buildings: Dictionary[Vector2i, BuildingData] = {} # key: Vector2i, value: BuildingData
var _building_nodes: Dictionary[Vector2i, Node2D] = {} # key: Vector2i, value: Node2D
var fluid_pipes: Array[PipeNode] = []
var fluid_sources: Array[WaterSourceNode] = []

const _GridUtils = preload("res://scripts/grid/grid_utils.gd")
const _BuildingFactory = preload("res://scripts/building/building_factory.gd")
const _FluidCoordinatorScript = preload("res://scripts/fluid/fluid_coordinator.gd")

@onready var pipe_render = $PipeRenderSystem


func _ready() -> void:
	_init_fluid_coordinator()

func _init_fluid_coordinator() -> void:
	if _FluidCoordinatorScript == null:
		return
	var coordinator = _FluidCoordinatorScript.new()
	if coordinator == null:
		return
	coordinator.name = "FluidCoordinator"
	coordinator.init(self)
	add_child(coordinator)

func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

func place_building(grid_pos: Vector2i, building_type: String = "default", restore_data: Dictionary = {}) -> bool:
	if has_building(grid_pos):
		return false

	var data := BuildingData.new()
	data.grid_position = grid_pos
	data.building_type = building_type

	var node_name = _GridUtils.get_building_node_name(grid_pos)
	var world_pos = GridCoordinate.grid_to_world(grid_pos)

	var building_node = _BuildingFactory.create_building(building_type, grid_pos, world_pos, node_name)
	add_child(building_node)

	if BuildingData.is_container_building(building_node) and not restore_data.is_empty():
		if restore_data.has("capacity"):
			data.capacity = restore_data["capacity"]
			building_node.capacity = restore_data["capacity"]
		if restore_data.has("max_capacity"):
			data.max_capacity = restore_data["max_capacity"]
			building_node.max_capacity = restore_data["max_capacity"]
	elif BuildingData.is_container_building(building_node):
		data.capacity = building_node.capacity
		data.max_capacity = building_node.max_capacity

	_building_nodes[grid_pos] = building_node
	if building_node is PipeNode:
		_register_pipe(building_node)
		fluid_pipes.append(building_node)
	elif building_node is WaterSourceNode:
		fluid_sources.append(building_node)
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
		data.capacity = node.capacity
		data.max_capacity = node.max_capacity
	node.queue_free()

	var node_to_remove = _building_nodes.get(grid_pos)
	if node_to_remove is PipeNode:
		_unregister_pipe(node_to_remove)
		fluid_pipes.erase(node_to_remove)
	elif node_to_remove is WaterSourceNode:
		fluid_sources.erase(node_to_remove)
	_building_nodes.erase(grid_pos)
	buildings.erase(grid_pos)
	EventBus.building_removed.emit(grid_pos)
	_refresh_pipe_connections(grid_pos)
	return true

func get_all_buildings_data() -> Dictionary:
	var copy: Dictionary = {}
	for grid_pos in buildings.keys():
		var data: BuildingData = buildings[grid_pos]
		var new_data := BuildingData.new()
		new_data.grid_position = data.grid_position
		new_data.building_type = data.building_type
		new_data.capacity = data.capacity
		new_data.max_capacity = data.max_capacity
		copy[grid_pos] = new_data
	return copy

func clear_all_buildings() -> void:
	for grid_pos in buildings.keys():
		remove_building(grid_pos)

func bulk_clear() -> void:
	for node in _building_nodes.values():
		node.queue_free()
	_building_nodes.clear()
	buildings.clear()
	fluid_pipes.clear()
	fluid_sources.clear()
	if pipe_render:
		pipe_render.clear_all()
	var coordinator := get_node_or_null("FluidCoordinator") as FluidCoordinator
	if coordinator:
		coordinator.mark_dirty()

func get_buildings_in_cells(cells: Array[Vector2i]) -> Dictionary:
	var result := {}
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


func batch_update_pipe_states(pipe_states: Dictionary) -> void:
	if pipe_render:
		pipe_render.batch_update_states(pipe_states)


func get_building_type(grid_pos: Vector2i) -> String:
	if buildings.has(grid_pos):
		return buildings[grid_pos].building_type
	return ""

func get_building_data(grid_pos: Vector2i) -> BuildingData:
	return buildings.get(grid_pos) as BuildingData

func get_building_node(grid_pos: Vector2i) -> Node:
	return _building_nodes.get(grid_pos) as Node

func is_fluid_building_at(grid_pos: Vector2i) -> bool:
	if not buildings.has(grid_pos):
		return false
	var data: BuildingData = buildings[grid_pos] as BuildingData
	return data != null and BuildingData.is_fluid_building(data.building_type)

func place_buildings_in_line(cells: Array[Vector2i], building_type: String = "default") -> int:
	var placed_count := 0
	for grid_pos in cells:
		if place_building(grid_pos, building_type):
			placed_count += 1
	return placed_count

func remove_buildings_in_rect(cells: Array[Vector2i]) -> int:
	var removed_count := 0
	for grid_pos in cells:
		if remove_building(grid_pos):
			removed_count += 1
	return removed_count

func _refresh_pipe_connections(grid_pos: Vector2i) -> void:
	for offset in GridCoordinate.DIR_4:
		var npos: Vector2i = grid_pos + offset
		if has_building(npos):
			var node := get_building_node(npos)
			if node is PipeNode:
				node.refresh_connections(is_fluid_building_at)

	var self_node := get_building_node(grid_pos)
	if self_node is PipeNode:
		self_node.refresh_connections(is_fluid_building_at)



