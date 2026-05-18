class_name InfiniteGridMap
extends Node2D

var loaded_blocks: Dictionary[Vector2i, bool] = {}
var block_pixel_size: int = 0

func _ready() -> void:
	block_pixel_size = GameConfig.cell_size * GameConfig.big_cell_size
	RenderingServer.set_default_clear_color(GameConfig.background_color)
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
	queue_redraw()

func _on_viewport_size_changed() -> void:
	update_visible_blocks()
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
	
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	var top_left: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.position)
	var bottom_right: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.end)
	
	var current_zoom: float = camera.zoom.x
	var adjusted_thin_width: float = GameConfig.thin_line_width / current_zoom
	var adjusted_thick_width: float = GameConfig.thick_line_width / current_zoom
	
	var visible_big_cells_x: float = view_rect.size.x / (block_pixel_size * current_zoom)
	var show_thin_lines: bool = visible_big_cells_x < 6
	
	if show_thin_lines:
		var thin_v_points := PackedVector2Array()
		var thin_h_points := PackedVector2Array()
		
		var min_x: float = top_left.x
		var max_x: float = bottom_right.x
		var min_y: float = top_left.y
		var max_y: float = bottom_right.y
		
		var start_cell_x: int = int(floor(min_x / GameConfig.cell_size))
		var end_cell_x: int = int(ceil(max_x / GameConfig.cell_size))
		var start_cell_y: int = int(floor(min_y / GameConfig.cell_size))
		var end_cell_y: int = int(ceil(max_y / GameConfig.cell_size))
		
		for cell_x in range(start_cell_x, end_cell_x):
			if cell_x % GameConfig.big_cell_size == 0:
				continue
			var line_x: float = cell_x * GameConfig.cell_size
			thin_v_points.append(Vector2(line_x, min_y))
			thin_v_points.append(Vector2(line_x, max_y))
		
		for cell_y in range(start_cell_y, end_cell_y):
			if cell_y % GameConfig.big_cell_size == 0:
				continue
			var line_y: float = cell_y * GameConfig.cell_size
			thin_h_points.append(Vector2(min_x, line_y))
			thin_h_points.append(Vector2(max_x, line_y))
		
		draw_multiline(thin_v_points, GameConfig.line_color, adjusted_thin_width)
		draw_multiline(thin_h_points, GameConfig.line_color, adjusted_thin_width)
	
	var thick_points := PackedVector2Array()
	for block_coord: Vector2i in loaded_blocks:
		var left: float = block_coord.x * block_pixel_size
		var top: float = block_coord.y * block_pixel_size
		var right: float = left + block_pixel_size
		var bottom: float = top + block_pixel_size
		thick_points.append(Vector2(left, top))
		thick_points.append(Vector2(left, bottom))
		thick_points.append(Vector2(left, top))
		thick_points.append(Vector2(right, top))
		thick_points.append(Vector2(right, top))
		thick_points.append(Vector2(right, bottom))
		thick_points.append(Vector2(left, bottom))
		thick_points.append(Vector2(right, bottom))
	draw_multiline(thick_points, GameConfig.line_color, adjusted_thick_width)
	
	var marker_size: float = GameConfig.cell_size * 2
	var marker_half: float = marker_size / 2.0
	var marker_rect: Rect2 = Rect2(Vector2(-marker_half, -marker_half), Vector2(marker_size, marker_size))
	draw_rect(marker_rect, Color.BLACK, true)

func mark_block_visible(block_coord: Vector2i) -> void:
	loaded_blocks[block_coord] = true
	queue_redraw()

func mark_block_hidden(block_coord: Vector2i) -> void:
	if loaded_blocks.has(block_coord):
		loaded_blocks.erase(block_coord)
		queue_redraw()


