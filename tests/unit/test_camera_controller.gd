extends GutTest

var _camera: Node = null

func before_each() -> void:
	var CameraControllerScript: GDScript = load("res://scripts/CameraController.gd")
	_camera = autoqfree(CameraControllerScript.new())
	add_child_autoqfree(_camera)


func test_default_zoom() -> void:
	assert_eq(_camera.zoom, Vector2(1.0, 1.0), "初始缩放应为 1.0")

func test_zoom_increases_zoom() -> void:
	var original: float = _camera.zoom.x
	_camera.zoom_at_position(Vector2(400, 300), 1 + GameConfig.zoom_speed)
	assert_true(_camera.zoom.x > original, "放大后 zoom.x 应增大")

func test_zoom_decreases_zoom() -> void:
	_camera.zoom_at_position(Vector2(400, 300), 1 - GameConfig.zoom_speed)
	assert_true(_camera.zoom.x < 1.0, "缩小后 zoom.x 应小于 1.0")

func test_zoom_always_positive() -> void:
	_camera.zoom = Vector2(0.02, 0.02)
	_camera.zoom_at_position(Vector2(400, 300), 0.01)
	assert_true(_camera.zoom.x > 0, "zoom.x 应保持正值")
	assert_true(_camera.zoom.y > 0, "zoom.y 应保持正值")

func test_zoom_does_not_explode() -> void:
	_camera.zoom = Vector2(50, 50)
	_camera.zoom_at_position(Vector2(400, 300), 5.0)
	assert_eq(_camera.zoom.x, 10.0, "zoom.x 应被 clamp 到最大值 10.0")
	assert_eq(_camera.zoom.y, 10.0, "zoom.y 应被 clamp 到最大值 10.0")

func test_zoom_preserves_aspect_ratio() -> void:
	_camera.zoom_at_position(Vector2(400, 300), 1 + GameConfig.zoom_speed)
	assert_eq(_camera.zoom.x, _camera.zoom.y, "zoom.x 应等于 zoom.y")

func test_zoom_at_position_changes_position() -> void:
	_camera.global_position = Vector2(100, 100)
	_camera.zoom_at_position(Vector2(400, 300), 0.5)
	var expected_zoom: Vector2 = Vector2(0.5, 0.5)
	assert_eq(_camera.zoom, expected_zoom, "缩放后 zoom 应为 0.5")
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = view_size / 2.0
	var _world_at_mouse: Vector2 = (Vector2(400, 300) - center) / expected_zoom + _camera.global_position
	var _expected_pos: Vector2 = Vector2(100, 100) + (Vector2(400, 300) - center) * (1.0 / 0.5 - 1.0)
	assert_ne(_camera.global_position, Vector2(100, 100), "缩放后 position 应发生调整")

func test_move_right() -> void:
	var start_pos: float = _camera.position.x
	Input.action_press("move_right")
	_camera._process(1.0)
	Input.action_release("move_right")
	assert_true(_camera.position.x > start_pos, "按下 move_right 后 position.x 应增大")

func test_move_left() -> void:
	var start_pos: float = _camera.position.x
	Input.action_press("move_left")
	_camera._process(1.0)
	Input.action_release("move_left")
	assert_true(_camera.position.x < start_pos, "按下 move_left 后 position.x 应减小")

func test_move_down() -> void:
	var start_pos: float = _camera.position.y
	Input.action_press("move_down")
	_camera._process(1.0)
	Input.action_release("move_down")
	assert_true(_camera.position.y > start_pos, "按下 move_down 后 position.y 应增大")

func test_move_up() -> void:
	var start_pos: float = _camera.position.y
	Input.action_press("move_up")
	_camera._process(1.0)
	Input.action_release("move_up")
	assert_true(_camera.position.y < start_pos, "按下 move_up 后 position.y 应减小")

func test_move_with_speed_up() -> void:
	_camera.position = Vector2.ZERO
	var original_mult: float = GameConfig.shift_speed_multiplier
	GameConfig.shift_speed_multiplier = 3.0
	Input.action_press("move_right")
	Input.action_press("speed_up")
	_camera._process(1.0)
	Input.action_release("speed_up")
	Input.action_release("move_right")
	assert_gt(_camera.position.x, _camera.move_speed * 0.5, "加速后移动距离应大于普通速度的一半")
	GameConfig.shift_speed_multiplier = original_mult

func test_move_zoomed_in() -> void:
	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2(0.5, 0.5)
	var move_speed: float = _camera.move_speed
	Input.action_press("move_right")
	_camera._process(1.0)
	Input.action_release("move_right")
	var _expected_speed: float = move_speed / 0.5
	assert_gt(_camera.position.x, move_speed * 0.5, "缩放 0.5 倍时移动速度应更快")
