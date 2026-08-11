class_name ElementRenderer
extends Node2D

var _element_visuals: Dictionary = {}

func _ready() -> void:
	EventBus.element_spawned.connect(_on_element_spawned)
	EventBus.element_removed.connect(_on_element_removed)
	EventBus.element_moved.connect(_on_element_moved)

func _exit_tree() -> void:
	if EventBus.element_spawned.is_connected(_on_element_spawned):
		EventBus.element_spawned.disconnect(_on_element_spawned)
	if EventBus.element_removed.is_connected(_on_element_removed):
		EventBus.element_removed.disconnect(_on_element_removed)
	if EventBus.element_moved.is_connected(_on_element_moved):
		EventBus.element_moved.disconnect(_on_element_moved)

func clear_all() -> void:
	_element_visuals.clear()
	queue_redraw()

func _on_element_spawned(grid_pos: Vector2i, element_type_id: String) -> void:
	var element_type: ElementTypeData = ElementRegistry.get_element_type(element_type_id)
	if element_type:
		_element_visuals[grid_pos] = element_type
		queue_redraw()

func _on_element_removed(grid_pos: Vector2i, _element_type_id: String) -> void:
	_element_visuals.erase(grid_pos)
	queue_redraw()

func _on_element_moved(from_grid_pos: Vector2i, to_grid_pos: Vector2i, _element_type_id: String) -> void:
	# 移动只更新两个键并合并为一次重绘，避免 removed+spawned 两次处理。
	# 前提：from 必然先经 element_spawned 记录（元素先生成后才会移动），缺失时防御性跳过
	var element_type: ElementTypeData = _element_visuals.get(from_grid_pos)
	if element_type != null:
		_element_visuals.erase(from_grid_pos)
		_element_visuals[to_grid_pos] = element_type
		queue_redraw()

func _draw() -> void:
	var element_size: float = GameConfig.BUILDING_SIZE * 0.8
	var half_size: float = element_size / 2.0
	# 内联 grid_to_world 的常量计算，避免每格一次函数调用
	var cell_size: float = float(GameConfig.CELL_SIZE)
	var world_offset: float = GameConfig.BUILDING_BORDER + GameConfig.BUILDING_SIZE / 2.0
	var element_rect_size := Vector2(element_size, element_size)

	for grid_pos: Vector2i in _element_visuals:
		var element_type: ElementTypeData = _element_visuals[grid_pos] as ElementTypeData
		var rect_pos := Vector2(
			grid_pos.x * cell_size + world_offset - half_size,
			grid_pos.y * cell_size + world_offset - half_size
		)

		var color: Color = element_type.color
		color.a = GameConfig.ELEMENT_ALPHA
		draw_rect(Rect2(rect_pos, element_rect_size), color)

		var border_color: Color = element_type.color
		border_color.a = 1.0
		draw_rect(Rect2(rect_pos, element_rect_size), border_color, false, 2.0)
