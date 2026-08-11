class_name InfiniteGridMap
extends Node2D

var loaded_blocks: Dictionary[Vector2i, bool] = {}
var block_pixel_size: int = 0

## 线段点缓存，仅在 visible_range 变化时重新计算，避免每帧重复构建
var _cached_thin_v_points: PackedVector2Array = PackedVector2Array()
var _cached_thin_h_points: PackedVector2Array = PackedVector2Array()
var _cached_thick_points: PackedVector2Array = PackedVector2Array()
var _cache_dirty: bool = true

func _ready() -> void:
	block_pixel_size = GameConfig.CELL_SIZE * GameConfig.BIG_CELL_SIZE
	RenderingServer.set_default_clear_color(GameConfig.BACKGROUND_COLOR)
	update_visible_blocks()
	queue_redraw()
	EventBus.camera_changed.connect(_on_camera_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _exit_tree() -> void:
	if EventBus.camera_changed.is_connected(_on_camera_changed):
		EventBus.camera_changed.disconnect(_on_camera_changed)
	if get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.disconnect(_on_viewport_size_changed)

func _on_camera_changed() -> void:
	update_visible_blocks()
	_cache_dirty = true
	queue_redraw()

func _on_viewport_size_changed() -> void:
	update_visible_blocks()
	_cache_dirty = true
	queue_redraw()



func get_visible_block_range() -> Dictionary:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return {"start_x": 0, "end_x": 0, "start_y": 0, "end_y": 0}
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	var top_left: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.position)
	var bottom_right: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.end)
	var start_block_x: int = floori(top_left.x / block_pixel_size)
	var end_block_x: int = floori(bottom_right.x / block_pixel_size)
	var start_block_y: int = floori(top_left.y / block_pixel_size)
	var end_block_y: int = floori(bottom_right.y / block_pixel_size)
	return {
		"start_x": start_block_x,
		"end_x": end_block_x,
		"start_y": start_block_y,
		"end_y": end_block_y
	}

func update_visible_blocks() -> void:
	var visible_range: Dictionary = get_visible_block_range()
	var current_blocks: Dictionary[Vector2i, bool] = {}
	
	for x in range(visible_range.start_x - 1, visible_range.end_x + 2):
		for y in range(visible_range.start_y - 1, visible_range.end_y + 2):
			var key: Vector2i = Vector2i(x, y)
			current_blocks[key] = true
			if not loaded_blocks.has(key):
				mark_block_visible(key)
	
	var blocks_to_unload: Array[Vector2i] = []
	for key: Vector2i in loaded_blocks:
		if not current_blocks.has(key):
			blocks_to_unload.append(key)
	for key: Vector2i in blocks_to_unload:
		mark_block_hidden(key)

func _draw() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return

	var current_zoom: float = camera.zoom.x
	var adjusted_thin_width: float = GameConfig.THIN_LINE_WIDTH / current_zoom
	var adjusted_thick_width: float = GameConfig.THICK_LINE_WIDTH / current_zoom

	# 仅在缓存失效时重新计算线段点
	if _cache_dirty:
		_rebuild_line_cache()
		_cache_dirty = false

	# draw_multiline 要求点数组非空且大小为偶数；
	# 缩放较大时 thin 线被隐藏（数组为空），跳过绘制避免引擎报错
	if not _cached_thin_v_points.is_empty():
		draw_multiline(_cached_thin_v_points, GameConfig.LINE_COLOR, adjusted_thin_width, true)
	if not _cached_thin_h_points.is_empty():
		draw_multiline(_cached_thin_h_points, GameConfig.LINE_COLOR, adjusted_thin_width, true)
	if not _cached_thick_points.is_empty():
		draw_multiline(_cached_thick_points, GameConfig.LINE_COLOR, adjusted_thick_width)

## 重建线段点缓存。根据当前视口和 loaded_blocks 计算 thin/thick 点数组。
func _rebuild_line_cache() -> void:
	_cached_thin_v_points.clear()
	_cached_thin_h_points.clear()
	_cached_thick_points.clear()

	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return

	var view_rect: Rect2 = get_viewport().get_visible_rect()
	var top_left: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.position)
	var bottom_right: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.end)

	var visible_big_cells_x: float = view_rect.size.x / (block_pixel_size * camera.zoom.x)
	var show_thin_lines: bool = visible_big_cells_x < GameConfig.THIN_LINE_VISIBLE_THRESHOLD

	if show_thin_lines:
		var min_x: float = top_left.x
		var max_x: float = bottom_right.x
		var min_y: float = top_left.y
		var max_y: float = bottom_right.y

		var start_cell_x: int = int(floor(min_x / GameConfig.CELL_SIZE))
		var end_cell_x: int = int(ceil(max_x / GameConfig.CELL_SIZE))
		var start_cell_y: int = int(floor(min_y / GameConfig.CELL_SIZE))
		var end_cell_y: int = int(ceil(max_y / GameConfig.CELL_SIZE))

		for cell_x in range(start_cell_x, end_cell_x):
			if cell_x % GameConfig.BIG_CELL_SIZE == 0:
				continue
			var line_x: float = cell_x * GameConfig.CELL_SIZE
			_cached_thin_v_points.append(Vector2(line_x, min_y))
			_cached_thin_v_points.append(Vector2(line_x, max_y))

		for cell_y in range(start_cell_y, end_cell_y):
			if cell_y % GameConfig.BIG_CELL_SIZE == 0:
				continue
			var line_y: float = cell_y * GameConfig.CELL_SIZE
			_cached_thin_h_points.append(Vector2(min_x, line_y))
			_cached_thin_h_points.append(Vector2(max_x, line_y))

	for block_coord: Vector2i in loaded_blocks:
		var left: float = block_coord.x * block_pixel_size
		var top: float = block_coord.y * block_pixel_size
		var right: float = left + block_pixel_size
		var bottom: float = top + block_pixel_size
		_cached_thick_points.append(Vector2(left, top))
		_cached_thick_points.append(Vector2(left, bottom))
		_cached_thick_points.append(Vector2(left, top))
		_cached_thick_points.append(Vector2(right, top))
		_cached_thick_points.append(Vector2(right, top))
		_cached_thick_points.append(Vector2(right, bottom))
		_cached_thick_points.append(Vector2(left, bottom))
		_cached_thick_points.append(Vector2(right, bottom))

func mark_block_visible(block_coord: Vector2i) -> void:
	loaded_blocks[block_coord] = true
	_cache_dirty = true
	queue_redraw()

func mark_block_hidden(block_coord: Vector2i) -> void:
	if loaded_blocks.has(block_coord):
		loaded_blocks.erase(block_coord)
		_cache_dirty = true
		queue_redraw()


