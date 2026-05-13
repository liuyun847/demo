class_name InfiniteGridMap
extends Node2D

var loaded_blocks: Dictionary[Vector2i, bool] = {}
var block_pixel_size: int = 0

func _ready() -> void:
	block_pixel_size = GameConfig.cell_size * GameConfig.big_cell_size
	update_visible_blocks()
	queue_redraw()

func _process(_delta: float) -> void:
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
				load_block(key)
	
	var blocks_to_unload: Array[Vector2i] = []
	for key: Vector2i in loaded_blocks:
		if not current_blocks.has(key):
			blocks_to_unload.append(key)
	for key: Vector2i in blocks_to_unload:
		unload_block(key)

func _draw() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	var top_left: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.position)
	var bottom_right: Vector2 = GridCoordinate.screen_to_world(camera, view_rect.end)
	
	draw_rect(Rect2(top_left, bottom_right - top_left), GameConfig.background_color)
	
	var current_zoom: float = camera.zoom.x
	var adjusted_thin_width: float = GameConfig.thin_line_width / current_zoom
	var adjusted_thick_width: float = GameConfig.thick_line_width / current_zoom
	
	var visible_big_cells_x: float = view_rect.size.x / (block_pixel_size * current_zoom)
	var show_thin_lines: bool = visible_big_cells_x < 6
	
	for block_coord: Vector2i in loaded_blocks.keys():
		var block_x: int = block_coord.x
		var block_y: int = block_coord.y
		var block_offset: Vector2 = Vector2(block_x * block_pixel_size, block_y * block_pixel_size)
		
		if show_thin_lines:
			for x in range(1, GameConfig.big_cell_size):
				var line_x: float = block_offset.x + x * GameConfig.cell_size
				draw_line(Vector2(line_x, block_offset.y), Vector2(line_x, block_offset.y + block_pixel_size), GameConfig.line_color, adjusted_thin_width)
			
			for y in range(1, GameConfig.big_cell_size):
				var line_y: float = block_offset.y + y * GameConfig.cell_size
				draw_line(Vector2(block_offset.x, line_y), Vector2(block_offset.x + block_pixel_size, line_y), GameConfig.line_color, adjusted_thin_width)
		
		draw_line(Vector2(block_offset.x, block_offset.y), Vector2(block_offset.x, block_offset.y + block_pixel_size), GameConfig.line_color, adjusted_thick_width)
		draw_line(Vector2(block_offset.x, block_offset.y), Vector2(block_offset.x + block_pixel_size, block_offset.y), GameConfig.line_color, adjusted_thick_width)
	
	var marker_size: float = GameConfig.cell_size * 2
	var marker_half: float = marker_size / 2.0
	var marker_rect: Rect2 = Rect2(Vector2(-marker_half, -marker_half), Vector2(marker_size, marker_size))
	draw_rect(marker_rect, Color.BLACK, true)

func load_block(block_coord: Vector2i) -> void:
	loaded_blocks[block_coord] = true
	queue_redraw()

func unload_block(block_coord: Vector2i) -> void:
	if loaded_blocks.has(block_coord):
		loaded_blocks.erase(block_coord)
		queue_redraw()


