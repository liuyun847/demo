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
