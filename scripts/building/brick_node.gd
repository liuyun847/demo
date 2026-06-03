class_name BrickNode
extends BuildingBase

func _ready() -> void:
	_setup_collision()

func _setup_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "StaticBody2D"

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(GameConfig.building_size, GameConfig.building_size)
	shape_node.shape = rect

	body.add_child(shape_node)
	shape_node.owner = body
	add_child(body)
	body.owner = self

func get_building_name() -> String:
	return "砖块"

func get_tooltip_summary() -> Dictionary:
	return {}

func _draw() -> void:
	var half := GameConfig.building_size / 2.0
	var w := float(GameConfig.building_size)

	var color_brick := Color(0.72, 0.25, 0.12)
	var color_line := Color(0.45, 0.15, 0.08, 0.6)
	var line_w := 1.0

	draw_rect(Rect2(-half, -half, w, w), color_brick)

	var third_h := w / 3.0
	for i in range(1, 3):
		draw_line(Vector2(-half, -half + third_h * i), Vector2(half, -half + third_h * i), color_line, line_w)

	var quarter_w := w / 4.0
	draw_line(Vector2(-half + quarter_w, -half), Vector2(-half + quarter_w, -half + third_h), color_line, line_w)
	draw_line(Vector2(-half + quarter_w * 3, -half), Vector2(-half + quarter_w * 3, -half + third_h), color_line, line_w)
	draw_line(Vector2(-half + quarter_w * 2, -half + third_h), Vector2(-half + quarter_w * 2, -half + third_h * 2), color_line, line_w)
	draw_line(Vector2(-half + quarter_w, -half + third_h * 2), Vector2(-half + quarter_w, half), color_line, line_w)
	draw_line(Vector2(-half + quarter_w * 3, -half + third_h * 2), Vector2(-half + quarter_w * 3, half), color_line, line_w)

	draw_rect(Rect2(-half, -half, w, w), Color(0.35, 0.12, 0.06), false, 1.5)
