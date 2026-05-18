class_name PipeRenderSystem
extends Node2D

var _pipe_positions: PackedVector2Array = PackedVector2Array()
var _pipe_masks: PackedInt32Array = PackedInt32Array()
var _pipe_states: PackedInt32Array = PackedInt32Array()
var _pipe_ids: PackedInt64Array = PackedInt64Array()
var _pipe_index_map: Dictionary[int, int] = {}
var _pipe_batch_mode: bool = false


func register_pipe(pipe: PipeNode) -> void:
	pipe.set_data_changed_callback(_pipe_data_changed)
	var id := pipe.get_instance_id()
	_pipe_index_map[id] = _pipe_positions.size()
	_pipe_positions.append(pipe.position)
	_pipe_masks.append(pipe.connection_mask)
	_pipe_states.append(pipe.network_state)
	_pipe_ids.append(id)


func unregister_pipe(pipe: PipeNode) -> void:
	pipe.set_data_changed_callback(Callable())
	var id := pipe.get_instance_id()
	var index: int = _pipe_index_map.get(id, -1)
	if index < 0:
		return
	var last := _pipe_positions.size() - 1
	if index != last:
		_pipe_positions[index] = _pipe_positions[last]
		_pipe_masks[index] = _pipe_masks[last]
		_pipe_states[index] = _pipe_states[last]
		var last_id := _pipe_ids[last]
		_pipe_ids[index] = last_id
		_pipe_index_map[last_id] = index
	_pipe_positions.resize(last)
	_pipe_masks.resize(last)
	_pipe_states.resize(last)
	_pipe_ids.resize(last)
	_pipe_index_map.erase(id)
	queue_redraw()


func _pipe_data_changed(pipe: PipeNode) -> void:
	var id := pipe.get_instance_id()
	var index: int = _pipe_index_map.get(id, -1)
	if index >= 0 and index < _pipe_positions.size():
		_pipe_masks[index] = pipe.connection_mask
		_pipe_states[index] = pipe.network_state
	if not _pipe_batch_mode:
		queue_redraw()


func batch_update_states(pipe_states: Dictionary) -> void:
	_pipe_batch_mode = true
	var needs_redraw := false
	for i in _pipe_ids.size():
		var id := _pipe_ids[i]
		var new_state: int = pipe_states.get(id, 0)
		if _pipe_states[i] != new_state:
			_pipe_states[i] = new_state
			needs_redraw = true
		var pipe := instance_from_id(id) as PipeNode
		if is_instance_valid(pipe) and pipe.network_state != new_state:
			pipe.network_state = new_state
	_pipe_batch_mode = false
	if needs_redraw:
		queue_redraw()


func clear_all() -> void:
	_pipe_positions.clear()
	_pipe_masks.clear()
	_pipe_states.clear()
	_pipe_ids.clear()
	_pipe_index_map.clear()


func _draw_pipes() -> void:
	if _pipe_positions.is_empty():
		return
	var half := GameConfig.building_size / 2.0
	var wall_w := 2.5
	var color_wall := Color(0.25, 0.25, 0.25)
	var passage_w := 14.0
	var pw := passage_w / 2.0

	for i in _pipe_positions.size():
		var pos := _pipe_positions[i]
		var mask := _pipe_masks[i]
		var state := _pipe_states[i]
		var cx := pos.x
		var cy := pos.y

		var color_bg: Color
		var color_passage: Color
		if state == 0:
			color_bg = Color(0.12, 0.12, 0.12)
			color_passage = Color(0.35, 0.35, 0.35)
		elif state == 1:
			color_bg = Color(0.12, 0.18, 0.25)
			color_passage = Color(0.3, 0.75, 1.0)
		else:
			color_bg = Color(0.10, 0.20, 0.10)
			color_passage = Color(0.2, 0.85, 0.2)

		draw_rect(Rect2(cx - half, cy - half, GameConfig.building_size, GameConfig.building_size), color_bg)

		if mask & GridCoordinate.DirFlag.LEFT:
			draw_rect(Rect2(cx - half, cy - pw, half, passage_w), color_passage)
		if mask & GridCoordinate.DirFlag.RIGHT:
			draw_rect(Rect2(cx, cy - pw, half, passage_w), color_passage)
		if mask & GridCoordinate.DirFlag.UP:
			draw_rect(Rect2(cx - pw, cy - half, passage_w, half), color_passage)
		if mask & GridCoordinate.DirFlag.DOWN:
			draw_rect(Rect2(cx - pw, cy, passage_w, half), color_passage)

		if mask != 0:
			draw_rect(Rect2(cx - pw, cy - pw, passage_w, passage_w), color_passage)

		draw_rect(Rect2(cx - half, cy - half, GameConfig.building_size, GameConfig.building_size), color_wall, false, wall_w)

		if mask & GridCoordinate.DirFlag.LEFT:
			draw_rect(Rect2(cx - half, cy - pw, wall_w, passage_w), color_passage)
		if mask & GridCoordinate.DirFlag.RIGHT:
			draw_rect(Rect2(cx + half - wall_w, cy - pw, wall_w, passage_w), color_passage)
		if mask & GridCoordinate.DirFlag.UP:
			draw_rect(Rect2(cx - pw, cy - half, passage_w, wall_w), color_passage)
		if mask & GridCoordinate.DirFlag.DOWN:
			draw_rect(Rect2(cx - pw, cy + half - wall_w, passage_w, wall_w), color_passage)


func _draw() -> void:
	_draw_pipes()
