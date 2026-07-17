class_name PipeRenderSystem
extends Node2D

# 渲染常量集中声明，避免每帧重复构造
const _PIPE_COLOR_BG: Color = Color(0.12, 0.12, 0.12)
const _PIPE_COLOR_PASSAGE: Color = Color(0.35, 0.35, 0.35)
const _PIPE_COLOR_WALL: Color = Color(0.25, 0.25, 0.25)
const _PIPE_PASSAGE_W: float = 14.0
const _PIPE_WALL_W: float = 2.5

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
	var half := GameConfig.BUILDING_SIZE / 2.0
	var pw := _PIPE_PASSAGE_W / 2.0
	var building_size := GameConfig.BUILDING_SIZE

	for i in _pipe_positions.size():
		var pos := _pipe_positions[i]
		var mask := _pipe_masks[i]
		var cx := pos.x
		var cy := pos.y

		draw_rect(Rect2(cx - half, cy - half, building_size, building_size), _PIPE_COLOR_BG)

		if mask & GridCoordinate.DirFlag.LEFT:
			draw_rect(Rect2(cx - half, cy - pw, half, _PIPE_PASSAGE_W), _PIPE_COLOR_PASSAGE)
		if mask & GridCoordinate.DirFlag.RIGHT:
			draw_rect(Rect2(cx, cy - pw, half, _PIPE_PASSAGE_W), _PIPE_COLOR_PASSAGE)
		if mask & GridCoordinate.DirFlag.UP:
			draw_rect(Rect2(cx - pw, cy - half, _PIPE_PASSAGE_W, half), _PIPE_COLOR_PASSAGE)
		if mask & GridCoordinate.DirFlag.DOWN:
			draw_rect(Rect2(cx - pw, cy, _PIPE_PASSAGE_W, half), _PIPE_COLOR_PASSAGE)

		if mask != 0:
			draw_rect(Rect2(cx - pw, cy - pw, _PIPE_PASSAGE_W, _PIPE_PASSAGE_W), _PIPE_COLOR_PASSAGE)

		draw_rect(Rect2(cx - half, cy - half, building_size, building_size), _PIPE_COLOR_WALL, false, _PIPE_WALL_W)

		if mask & GridCoordinate.DirFlag.LEFT:
			draw_rect(Rect2(cx - half, cy - pw, _PIPE_WALL_W, _PIPE_PASSAGE_W), _PIPE_COLOR_PASSAGE)
		if mask & GridCoordinate.DirFlag.RIGHT:
			draw_rect(Rect2(cx + half - _PIPE_WALL_W, cy - pw, _PIPE_WALL_W, _PIPE_PASSAGE_W), _PIPE_COLOR_PASSAGE)
		if mask & GridCoordinate.DirFlag.UP:
			draw_rect(Rect2(cx - pw, cy - half, _PIPE_PASSAGE_W, _PIPE_WALL_W), _PIPE_COLOR_PASSAGE)
		if mask & GridCoordinate.DirFlag.DOWN:
			draw_rect(Rect2(cx - pw, cy + half - _PIPE_WALL_W, _PIPE_PASSAGE_W, _PIPE_WALL_W), _PIPE_COLOR_PASSAGE)


func _draw() -> void:
	_draw_pipes()
