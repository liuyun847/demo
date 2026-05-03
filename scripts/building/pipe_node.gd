class_name PipeNode
extends Node2D

enum ConnectionDir {
	TOP = 1,
	RIGHT = 2,
	BOTTOM = 4,
	LEFT = 8,
}

@export var grid_position: Vector2i

@export var capacity: int = 0:
	set(value):
		capacity = clampi(value, 0, max_capacity)
		queue_redraw()

@export var max_capacity: int = 5:
	set(value):
		max_capacity = maxi(value, 1)
		capacity = mini(capacity, max_capacity)
		queue_redraw()

var connection_mask: int = 0:
	set(value):
		connection_mask = value
		queue_redraw()

func get_fill_ratio() -> float:
	return float(capacity) / float(max_capacity)

func add(amount: int) -> int:
	var old := capacity
	capacity = clampi(capacity + amount, 0, max_capacity)
	return capacity - old

func remove(amount: int) -> int:
	var old := capacity
	capacity = clampi(capacity - amount, 0, max_capacity)
	return old - capacity

func refresh_connections() -> void:
	var bm := get_parent()
	if not bm or not bm is BuildingManager:
		return

	var my_pos := _get_grid_position()
	var mask := 0

	if _is_connectable_at(bm, my_pos + Vector2i(0, -1)):
		mask |= ConnectionDir.TOP
	if _is_connectable_at(bm, my_pos + Vector2i(1, 0)):
		mask |= ConnectionDir.RIGHT
	if _is_connectable_at(bm, my_pos + Vector2i(0, 1)):
		mask |= ConnectionDir.BOTTOM
	if _is_connectable_at(bm, my_pos + Vector2i(-1, 0)):
		mask |= ConnectionDir.LEFT

	connection_mask = mask

func _get_grid_position() -> Vector2i:
	return grid_position

static func is_connectable(node: Node) -> bool:
	return node is PipeNode or node is ContainerNode

func _is_connectable_at(bm: BuildingManager, grid_pos: Vector2i) -> bool:
	if not bm.buildings.has(grid_pos):
		return false
	var building_data: BuildingData = bm.buildings[grid_pos] as BuildingData
	if not building_data:
		return false
	return building_data.building_type == GameConfig.pipe_type_id or building_data.building_type == GameConfig.container_type_id

func _draw() -> void:
	var half := GameConfig.building_size / 2.0
	var wall_w := 2.5

	var color_bg := Color(0.12, 0.12, 0.12)
	var color_passage := Color(0.38, 0.38, 0.38)
	var color_wall := Color(0.25, 0.25, 0.25)
	var color_filled := Color.WHITE

	var passage_w := 14.0
	var pw := passage_w / 2.0

	draw_rect(Rect2(-half, -half, GameConfig.building_size, GameConfig.building_size), color_bg)

	var has_h := (connection_mask & (ConnectionDir.LEFT | ConnectionDir.RIGHT)) != 0
	var has_v := (connection_mask & (ConnectionDir.TOP | ConnectionDir.BOTTOM)) != 0

	if has_h:
		draw_rect(Rect2(-half, -pw, GameConfig.building_size, passage_w), color_passage)

	if has_v:
		draw_rect(Rect2(-pw, -half, passage_w, GameConfig.building_size), color_passage)

	if not has_h and not has_v:
		draw_rect(Rect2(-pw, -pw, passage_w, passage_w), color_passage)

	if has_h and has_v:
		draw_rect(Rect2(-pw, -pw, passage_w, passage_w), color_passage)

	draw_rect(Rect2(-half, -half, GameConfig.building_size, GameConfig.building_size), color_wall, false, wall_w)

	if connection_mask & ConnectionDir.LEFT:
		draw_rect(Rect2(-half, -pw, wall_w, passage_w), color_passage)
	if connection_mask & ConnectionDir.RIGHT:
		draw_rect(Rect2(half - wall_w, -pw, wall_w, passage_w), color_passage)
	if connection_mask & ConnectionDir.TOP:
		draw_rect(Rect2(-pw, -half, passage_w, wall_w), color_passage)
	if connection_mask & ConnectionDir.BOTTOM:
		draw_rect(Rect2(-pw, half - wall_w, passage_w, wall_w), color_passage)

	var fill_ratio := get_fill_ratio()
	if fill_ratio > 0.0:
		var fill_w := 8.0
		var fill_h := (GameConfig.building_size - wall_w * 2.0) * fill_ratio
		draw_rect(Rect2(-fill_w / 2.0, half - wall_w - fill_h, fill_w, fill_h), color_filled)
