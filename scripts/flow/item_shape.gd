class_name ItemShape
extends Node2D

## 物品色块形状：数字=圆形，操作=圆角方形（单独文件以便 set_script 挂载）。

var is_op: bool = false
var color: Color = Color.WHITE
var radius: float = 14.0

const BORDER_COLOR: Color = Color(0.1, 0.1, 0.1, 0.9)

func _draw() -> void:
	if is_op:
		var side := radius * 1.7
		var rect := Rect2(-side / 2.0, -side / 2.0, side, side)
		draw_rect(rect, color)
		draw_rect(rect, BORDER_COLOR, false, 2.0)
	else:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, BORDER_COLOR, 2.0)