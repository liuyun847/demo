class_name FluidCoordinator
extends Node

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

func _on_tick() -> void:
	var nodes := get_tree().get_nodes_in_group("fluid_node")
	if nodes.is_empty():
		return

	for node in nodes:
		if node is WaterSourceNode:
			node.remaining_output = node.output_per_tick

	var has_flow := false

	for _iter in range(GameConfig.fluid_sub_iterations):
		var transfers: Array[Dictionary] = []
		var committed_output: Dictionary = {}

		for node in nodes:
			if node.has_method("collect_transfers"):
				node.collect_transfers(transfers)

		if transfers.is_empty():
			break

		has_flow = true

		for t in transfers:
			var src: Node = t.src
			var dst: Node = t.dst
			var amount: int = t.amount

			if src.has_method("get_pressure") and not src is WaterSourceNode:
				var src_id := src.get_instance_id()
				var committed: int = committed_output.get(src_id, 0)
				if src.capacity - committed < amount:
					continue
				committed_output[src_id] = committed + amount
				src.remove(amount)
				_sync_building_data(src)

			if dst.has_method("add"):
				dst.add(amount)
			else:
				dst.capacity = clampi(dst.capacity + amount, 0, dst.max_capacity)

			if src is WaterSourceNode:
				src.remaining_output -= amount

			_sync_building_data(dst)

	if has_flow:
		EventBus.fluid_updated.emit()

func _sync_building_data(node: Node) -> void:
	var bm = node.get_parent()
	if bm != null and bm.has_method("has_building") and bm.buildings.has(node.grid_position):
		bm.buildings[node.grid_position].capacity = node.capacity
