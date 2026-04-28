extends Node2D

var cell_size: int
var big_cell_size: int
var thin_line_width: float
var thick_line_width: float
var background_color: Color
var line_color: Color

var viewport: Viewport
var loaded_blocks: Dictionary = {}
var block_pixel_size: int = 0

func _ready() -> void:
	cell_size = GameConfig.cell_size
	big_cell_size = GameConfig.big_cell_size
	thin_line_width = GameConfig.thin_line_width
	thick_line_width = GameConfig.thick_line_width
	background_color = GameConfig.background_color
	line_color = GameConfig.line_color
	viewport = get_viewport()
	block_pixel_size = cell_size * big_cell_size
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	update_visible_blocks()
	queue_redraw()



func get_visible_block_range() -> Dictionary:
	var camera = viewport.get_camera_2d()
	if not camera:
		return {"start_x": 0, "end_x": 0, "start_y": 0, "end_y": 0}
	var view_rect = viewport.get_visible_rect()
	var top_left = GridCoordinate.screen_to_world(camera, view_rect.position)
	var bottom_right = GridCoordinate.screen_to_world(camera, view_rect.end)
	var start_block_x = floori(top_left.x / block_pixel_size)
	var end_block_x = floori(bottom_right.x / block_pixel_size)
	var start_block_y = floori(top_left.y / block_pixel_size)
	var end_block_y = floori(bottom_right.y / block_pixel_size)
	return {
		"start_x": start_block_x,
		"end_x": end_block_x,
		"start_y": start_block_y,
		"end_y": end_block_y
	}

func update_visible_blocks() -> void:
	var visible_range = get_visible_block_range()
	var current_blocks = {}
	
	for x in range(visible_range.start_x - 1, visible_range.end_x + 2):
		for y in range(visible_range.start_y - 1, visible_range.end_y + 2):
			var key = Vector2i(x, y)
			current_blocks[key] = true
			if not loaded_blocks.has(key):
				load_block(key)
	
	var blocks_to_unload: Array[Vector2i] = []
	for key in loaded_blocks:
		if not current_blocks.has(key):
			blocks_to_unload.append(key)
	for key in blocks_to_unload:
		unload_block(key)

func _draw() -> void:
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	var view_rect = viewport.get_visible_rect()
	var top_left = GridCoordinate.screen_to_world(camera, view_rect.position)
	var bottom_right = GridCoordinate.screen_to_world(camera, view_rect.end)
	
	draw_rect(Rect2(top_left, bottom_right - top_left), background_color)
	
	var current_zoom = camera.zoom.x
	var adjusted_thin_width = thin_line_width / current_zoom
	var adjusted_thick_width = thick_line_width / current_zoom
	
	var visible_big_cells_x = view_rect.size.x / (block_pixel_size * current_zoom)
	var show_thin_lines = visible_big_cells_x < 6
	
	for block_coord in loaded_blocks.keys():
		var block_x = block_coord.x
		var block_y = block_coord.y
		var block_offset = Vector2(block_x * block_pixel_size, block_y * block_pixel_size)
		
		if show_thin_lines:
			for x in range(1, big_cell_size):
				var line_x = block_offset.x + x * cell_size
				draw_line(Vector2(line_x, block_offset.y), Vector2(line_x, block_offset.y + block_pixel_size), line_color, adjusted_thin_width)
			
			for y in range(1, big_cell_size):
				var line_y = block_offset.y + y * cell_size
				draw_line(Vector2(block_offset.x, line_y), Vector2(block_offset.x + block_pixel_size, line_y), line_color, adjusted_thin_width)
		
		draw_line(Vector2(block_offset.x + block_pixel_size, block_offset.y), Vector2(block_offset.x + block_pixel_size, block_offset.y + block_pixel_size), line_color, adjusted_thick_width)
		draw_line(Vector2(block_offset.x, block_offset.y + block_pixel_size), Vector2(block_offset.x + block_pixel_size, block_offset.y + block_pixel_size), line_color, adjusted_thick_width)
		
		if block_x == 0 and block_y == 0:
			draw_line(Vector2(block_offset.x, block_offset.y), Vector2(block_offset.x, block_offset.y + block_pixel_size), line_color, adjusted_thick_width)
			draw_line(Vector2(block_offset.x, block_offset.y), Vector2(block_offset.x + block_pixel_size, block_offset.y), line_color, adjusted_thick_width)
	
	var center_box_size = cell_size * 0.8
	var center_box_offset = cell_size * 0.1
	var center_box_rect = Rect2(Vector2(center_box_offset, center_box_offset), Vector2(center_box_size, center_box_size))
	draw_rect(center_box_rect, Color.BLACK, false, 2.0 / current_zoom)

func load_block(block_coord: Vector2i) -> void:
	loaded_blocks[block_coord] = true
	queue_redraw()

func unload_block(block_coord: Vector2i) -> void:
	if loaded_blocks.has(block_coord):
		loaded_blocks.erase(block_coord)
		queue_redraw()


