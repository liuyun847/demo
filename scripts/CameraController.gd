class_name CameraController
extends Camera2D

@export var move_speed: float = 200.0 # 移动速度（像素/秒）

## UIOverlay 引用缓存：菜单/设置全屏面板打开时屏蔽相机输入（WASD 移动与滚轮缩放），
## 防止按键穿透到世界。仅在同场景树内可用；裸节点（测试）无 UIOverlay 时不做守卫。
var _ui_overlay: CanvasLayer = null

func _ready() -> void:
	# 初始化缩放
	zoom = Vector2(1.0, 1.0)
	_ui_overlay = get_node_or_null("../UIOverlay") as CanvasLayer

## UI 全屏面板（开始菜单/设置面板）是否可见：可见时相机不应响应世界输入
func _ui_blocking() -> bool:
	if _ui_overlay == null:
		return false
	var menu := _ui_overlay.get_node_or_null("StartMenu") as Control
	if menu != null and menu.visible:
		return true
	var settings := _ui_overlay.get_node_or_null("SettingsPanel") as Control
	return settings != null and settings.visible

func _unhandled_input(event: InputEvent) -> void:
	if _ui_blocking():
		return
	if event.is_action_pressed("zoom_in"):
		zoom_at_position(event.position, 1 + GameConfig.zoom_speed)
	elif event.is_action_pressed("zoom_out"):
		zoom_at_position(event.position, 1 - GameConfig.zoom_speed)
	elif event.is_action_pressed("focus_core"):
		# 视口移回核心（世界原点）。核心占据 (-1,-1)..(0,0)，视觉中心即原点，不可移动
		position = Vector2.ZERO

# 在指定位置进行缩放
func zoom_at_position(screen_pos: Vector2, factor: float) -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = view_size / 2.0
	if screen_pos == Vector2.ZERO:
		screen_pos = center
	var world_pos: Vector2 = (screen_pos - center) / zoom + global_position
	zoom *= factor
	zoom = Vector2(clamp(zoom.x, 0.1, 10.0), clamp(zoom.y, 0.1, 10.0))

	# 调整位置保持鼠标指向的位置不变
	var new_world_pos: Vector2 = (screen_pos - center) / zoom + global_position
	position += (world_pos - new_world_pos)
	# 标记脏，由 _process 统一 emit，避免同帧多次 emit
	_zoom_dirty = true

var _last_process_pos: Vector2
var _last_zoom: Vector2
var _zoom_dirty: bool = false

func _process(delta: float) -> void:
	if _ui_blocking():
		return  # 菜单/设置打开：不响应 WASD 移动（按键穿透防护）
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

	# 统一在 _process 中 emit，避免 zoom_at_position 与 _process 同帧各 emit 一次
	if _zoom_dirty or position != _last_process_pos or zoom != _last_zoom:
		_zoom_dirty = false
		_last_process_pos = position
		_last_zoom = zoom
		EventBus.camera_changed.emit()
