class_name ElementRenderer
extends Node2D

var _element_visuals: Dictionary = {}

func _ready() -> void:
	EventBus.element_spawned.connect(_on_element_spawned)
	EventBus.element_removed.connect(_on_element_removed)

func _exit_tree() -> void:
	if EventBus.element_spawned.is_connected(_on_element_spawned):
		EventBus.element_spawned.disconnect(_on_element_spawned)
	if EventBus.element_removed.is_connected(_on_element_removed):
		EventBus.element_removed.disconnect(_on_element_removed)

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

func _draw() -> void:
	var element_size: float = GameConfig.building_size * 0.8

	for grid_pos: Variant in _element_visuals:
		var element_type: ElementTypeData = _element_visuals[grid_pos] as ElementTypeData
		var world_pos: Vector2 = GridCoordinate.grid_to_world(grid_pos)
		var rect_pos: Vector2 = world_pos - Vector2(element_size, element_size) / 2.0

		var color: Color = element_type.color
		color.a = 0.85
		draw_rect(Rect2(rect_pos, Vector2(element_size, element_size)), color)

		var border_color: Color = element_type.color
		border_color.a = 1.0
		draw_rect(Rect2(rect_pos, Vector2(element_size, element_size)), border_color, false, 2.0)
