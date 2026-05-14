class_name CameraController
extends Camera2D

@export var move_speed: float = 200.0 # 移动速度（像素/秒）

func _ready() -> void:
	# 初始化缩放
	zoom = Vector2(1.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("zoom_in"):
		zoom_at_position(event.position, 1 + GameConfig.zoom_speed)
	elif event.is_action_pressed("zoom_out"):
		zoom_at_position(event.position, 1 - GameConfig.zoom_speed)

# 在指定位置进行缩放
func zoom_at_position(screen_pos: Vector2, factor: float) -> void:
	var view_size = get_viewport().get_visible_rect().size
	var center = view_size / 2.0
	if screen_pos == Vector2.ZERO:
		screen_pos = center
	var world_pos = (screen_pos - center) / zoom + global_position
	zoom *= factor
	zoom = Vector2(clamp(zoom.x, 0.1, 10.0), clamp(zoom.y, 0.1, 10.0))

	# 调整位置保持鼠标指向的位置不变
	var new_world_pos = (screen_pos - center) / zoom + global_position
	position += (world_pos - new_world_pos)

func _process(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		var current_speed: float = move_speed
		if Input.is_action_pressed("speed_up"):
			current_speed *= GameConfig.shift_speed_multiplier
		position += input_dir * current_speed * delta / zoom.x
