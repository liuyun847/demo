class_name PipeNode
extends BuildingBase

var _data_changed_callback: Callable

func set_data_changed_callback(cb: Callable) -> void:
	_data_changed_callback = cb

var connection_mask: int = 0:
	set(value):
		if connection_mask != value:
			connection_mask = value
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


func get_building_name() -> String:
	return "管道"

func get_tooltip_summary() -> Dictionary:
	return {}

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
