class_name ContainerNode
extends FluidNodeBase

var _redraw_pending: bool = false

@export var capacity: int = 0:
	set(value):
		capacity = clampi(value, 0, max_capacity)
		_mark_redraw()

@export var max_capacity: int = 100:
	set(value):
		max_capacity = maxi(value, 1)
		if capacity > max_capacity:
			capacity = max_capacity
		_mark_redraw()


func _mark_redraw() -> void:
	if not _redraw_pending:
		_redraw_pending = true
		call_deferred("_do_redraw")


func _do_redraw() -> void:
	_redraw_pending = false
	queue_redraw()


func _ready() -> void:
	add_to_group("container")

func get_fill_ratio() -> float:
	return float(capacity) / float(max_capacity)


func get_pressure() -> float:
	return 0.0


func add(amount: int) -> int:
	var old := capacity
	capacity = clampi(capacity + amount, 0, max_capacity)
	return capacity - old


func remove(amount: int) -> int:
	var old := capacity
	capacity = clampi(capacity - amount, 0, max_capacity)
	return old - capacity


func get_building_name() -> String:
	return "容器"

func get_tooltip_summary() -> Dictionary:
	return {
		"容量": "%d / %d" % [capacity, max_capacity],
	}

func get_tooltip_details() -> Dictionary:
	return {
		"填充率": "%d%%" % int(get_fill_ratio() * 100.0),
		"压力": "%.2f" % get_pressure(),
	}

func _draw() -> void:
	var half_size: float = GameConfig.building_size / 2.0
	var wall_w: float = 4.0
	var inner_left: float = - half_size + wall_w
	var inner_w: float = GameConfig.building_size - wall_w * 2.0
	var total_h: float = GameConfig.building_size
	var fill_ratio: float = get_fill_ratio()

	var color_wall: Color = Color(0.35, 0.35, 0.35)
	var color_empty: Color = Color(0.15, 0.15, 0.15)
	var color_filled: Color = Color.WHITE

	var left_wall := Rect2(-half_size, -half_size, wall_w, total_h)
	draw_rect(left_wall, color_wall)

	var right_wall := Rect2(half_size - wall_w, -half_size, wall_w, total_h)
	draw_rect(right_wall, color_wall)

	var _fill_area := Rect2(inner_left, -half_size, inner_w, total_h)
	var fill_h: float = total_h * fill_ratio

	if fill_h > 0:
		var filled_rect := Rect2(inner_left, half_size - fill_h, inner_w, fill_h)
		draw_rect(filled_rect, color_filled)

	if fill_h < total_h:
		var empty_h: float = total_h - fill_h
		var empty_rect := Rect2(inner_left, -half_size, inner_w, empty_h)
		draw_rect(empty_rect, color_empty)

	var border := Rect2(-half_size, -half_size, GameConfig.building_size, GameConfig.building_size)
	draw_rect(border, Color(0.25, 0.25, 0.25), false, 1.5)
