class_name PipeNode
extends FluidNodeBase

var _data_changed_callback: Callable

func set_data_changed_callback(cb: Callable) -> void:
	_data_changed_callback = cb

var connection_mask: int = 0:
	set(value):
		connection_mask = value
		_notify_bm_dirty()

var network_state: int = 0:
	set(value):
		if network_state != value:
			network_state = value
			_notify_bm_dirty()


func _notify_bm_dirty() -> void:
	if _data_changed_callback.is_valid():
		_data_changed_callback.call(self)

func _ready() -> void:
	add_to_group("pipe")

func refresh_connections(is_connectable: Callable) -> void:
	var my_pos := grid_position
	var mask := 0

	if is_connectable.call(my_pos + Vector2i(0, -1)):
		mask |= GridCoordinate.DirFlag.UP
	if is_connectable.call(my_pos + Vector2i(1, 0)):
		mask |= GridCoordinate.DirFlag.RIGHT
	if is_connectable.call(my_pos + Vector2i(0, 1)):
		mask |= GridCoordinate.DirFlag.DOWN
	if is_connectable.call(my_pos + Vector2i(-1, 0)):
		mask |= GridCoordinate.DirFlag.LEFT

	connection_mask = mask

func get_pressure() -> float:
	return 0.0


func get_building_name() -> String:
	return "管道"

func get_tooltip_summary() -> Dictionary:
	var state_text := "未连通"
	if network_state == 1:
		state_text = "输送中"
	elif network_state == 2:
		state_text = "已满载"
	return {"网络状态": state_text}

func get_tooltip_details() -> Dictionary:
	var connections: Array[String] = []
	if connection_mask & GridCoordinate.DirFlag.UP:
		connections.append("上")
	if connection_mask & GridCoordinate.DirFlag.DOWN:
		connections.append("下")
	if connection_mask & GridCoordinate.DirFlag.LEFT:
		connections.append("左")
	if connection_mask & GridCoordinate.DirFlag.RIGHT:
		connections.append("右")
	var conn_str := "无" if connections.is_empty() else "、".join(connections)
	return {
		"连接方向": conn_str,
	}

func _draw() -> void:
	pass
