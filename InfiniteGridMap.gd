extends Node2D

@export var cell_size: int = 64
@export var big_cell_size: int = 10
@export var thin_line_width: float = 1.0
@export var thick_line_width: float = 3.0
@export var background_color: Color = Color("#1e3a5f")
@export var line_color: Color = Color("#e0e0e0", 0.5)

const SAVE_FILE_PATH: String = "res://save/buildings.json" # TODO: 开发阶段临时使用res路径，导出前需修改为"user://save/buildings.json"

var viewport: Viewport
var loaded_blocks: Dictionary = {}
var block_pixel_size: int = 0
var buildings: Dictionary = {} # 存储已放置的建筑，key为Vector2i网格坐标

func _ready() -> void:
	viewport = get_viewport()
	block_pixel_size = cell_size * big_cell_size
	set_process(true)
	set_process_unhandled_input(true)
	# 加载已保存的建筑
	load_buildings()
	queue_redraw()

func _process(_delta: float) -> void:
	update_visible_blocks()
	queue_redraw()

func screen_to_world(camera: Camera2D, screen_pos: Vector2) -> Vector2:
	var view_size = viewport.get_visible_rect().size
	var center = view_size / 2.0
	var offset = (screen_pos - center) / camera.zoom
	return offset + camera.global_position

func get_visible_block_range() -> Dictionary:
	var camera = viewport.get_camera_2d()
	if not camera:
		return {"start_x": 0, "end_x": 0, "start_y": 0, "end_y": 0}
	var view_rect = viewport.get_visible_rect()
	var top_left = screen_to_world(camera, view_rect.position)
	var bottom_right = screen_to_world(camera, view_rect.end)
	var start_block_x = floor(top_left.x / block_pixel_size)
	var end_block_x = floor(bottom_right.x / block_pixel_size)
	var start_block_y = floor(top_left.y / block_pixel_size)
	var end_block_y = floor(bottom_right.y / block_pixel_size)
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
	var top_left = screen_to_world(camera, view_rect.position)
	var bottom_right = screen_to_world(camera, view_rect.end)
	
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
	
	# 绘制地图中心标注方框
	var center_box_size = cell_size * 0.8
	var center_box_offset = cell_size * 0.1
	var center_box_rect = Rect2(Vector2(center_box_offset, center_box_offset), Vector2(center_box_size, center_box_size))
	draw_rect(center_box_rect, Color.BLACK, false, 2.0 / current_zoom)

func load_block(block_coord: Vector2i) -> void:
	# 当前仅标记区块为已加载状态，实际资源加载逻辑可在此处扩展
	# 后续可根据需求实现以下功能：
	# 1. 加载对应区块的网格纹理/材质资源
	# 2. 生成/加载地形数据
	# 3. 实例化区块内的游戏对象、场景节点
	# 4. 预加载区块相关的音频、动画等资源
	loaded_blocks[block_coord] = true
	queue_redraw()

func unload_block(block_coord: Vector2i) -> void:
	if loaded_blocks.has(block_coord):
		loaded_blocks.erase(block_coord)
		# 对应load_block的资源卸载逻辑可在此处实现
		# 1. 释放区块占用的纹理、材质等资源
		# 2. 销毁区块内的游戏对象、场景节点
		# 3. 清理地形数据缓存
		queue_redraw()

# 将世界坐标转换为网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floor(world_pos.x / cell_size),
		floor(world_pos.y / cell_size)
	)

# 检查指定网格位置是否已有建筑
func has_building(grid_pos: Vector2i) -> bool:
	return buildings.has(grid_pos)

# 在指定网格位置放置建筑
func place_building(grid_pos: Vector2i) -> bool:
	if has_building(grid_pos):
		return false
	# 创建建筑实例（直接创建ColorRect作为占位）
	var building = ColorRect.new()
	building.size = Vector2(60, 60)
	building.color = Color("#2ecc71")
	# 设置建筑位置，留2像素边框
	building.global_position = Vector2(
		grid_pos.x * cell_size + 2,
		grid_pos.y * cell_size + 2
	)
	add_child(building)
	# 记录建筑数据
	buildings[grid_pos] = building
	# 保存到文件
	save_buildings()
	return true

# 保存建筑数据到文件
func save_buildings() -> void:
	# 确保save目录存在
	DirAccess.make_dir_recursive_absolute(SAVE_FILE_PATH.get_base_dir()) # 目录路径获取正确，开发完成后路径修改为user://时无需改动这行
	# 转换建筑数据为可序列化格式
	var save_data: Array = []
	for grid_pos in buildings.keys():
		save_data.append([grid_pos.x, grid_pos.y])
	# 写入文件
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

# 从文件加载建筑数据
func load_buildings() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var save_data = JSON.parse_string(content)
	if not save_data is Array:
		return
	# 加载所有建筑
	for data in save_data:
		if data.size() == 2:
			var grid_pos = Vector2i(data[0], data[1])
			place_building(grid_pos)

# 处理输入事件
func _unhandled_input(event: InputEvent) -> void:
	# 处理鼠标左键点击
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera = viewport.get_camera_2d()
		if not camera:
			return
		# 将鼠标屏幕坐标转成世界坐标
		var world_pos = screen_to_world(camera, event.position)
		# 转成网格坐标
		var grid_pos = world_to_grid(world_pos)
		# 放置建筑
		place_building(grid_pos)
