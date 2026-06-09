class_name PipeRenderSystem
extends Node2D

var _pipe_positions: PackedVector2Array = PackedVector2Array()
var _pipe_masks: PackedInt32Array = PackedInt32Array()
var _pipe_refs: Array[PipeNode] = []
var _pipe_index_map: Dictionary = {}


func register_pipe(pipe: PipeNode) -> void:
	pipe.set_data_changed_callback(_pipe_data_changed)
	_pipe_index_map[pipe] = _pipe_positions.size()
	_pipe_positions.append(pipe.position)
	_pipe_masks.append(pipe.connection_mask)
	_pipe_refs.append(pipe)


func unregister_pipe(pipe: PipeNode) -> void:
	pipe.set_data_changed_callback(Callable())
	if not _pipe_index_map.has(pipe):
		return
	var index: int = _pipe_index_map[pipe]
	var last := _pipe_positions.size() - 1
	if index != last:
		_pipe_positions[index] = _pipe_positions[last]
		_pipe_masks[index] = _pipe_masks[last]
		var last_pipe: PipeNode = _pipe_refs[last]
		_pipe_refs[index] = last_pipe
		_pipe_index_map[last_pipe] = index
	_pipe_positions.resize(last)
	_pipe_masks.resize(last)
	_pipe_refs.resize(last)
	_pipe_index_map.erase(pipe)
	queue_redraw()


func _pipe_data_changed(pipe: PipeNode) -> void:
	var index: int = _pipe_index_map.get(pipe, -1)
	if index >= 0 and index < _pipe_positions.size():
		_pipe_masks[index] = pipe.connection_mask
	queue_redraw()


func clear_all() -> void:
	_pipe_positions.clear()
	_pipe_masks.clear()
	_pipe_refs.clear()
	_pipe_index_map.clear()


func _draw_pipes() -> void:
	if _pipe_positions.is_empty():
		return
	var half := GameConfig.building_size / 2.0
	var color_bg := Color(0.12, 0.12, 0.12)
	var color_passage := Color(0.35, 0.35, 0.35)
	var color_wall := Color(0.25, 0.25, 0.25)
	var passage_w := 14.0
	var pw := passage_w / 2.0
	var wall_w := 2.5

	for i in _pipe_positions.size():
		var pos := _pipe_positions[i]
		var mask := _pipe_masks[i]
		var cx := pos.x
		var cy := pos.y

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
