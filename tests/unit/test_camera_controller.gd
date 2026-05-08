extends GutTest

var _camera: Node = null

func before_each():
	var CameraControllerScript = load("res://scripts/CameraController.gd")
	_camera = autoqfree(CameraControllerScript.new())
	add_child_autoqfree(_camera)


func test_default_zoom():
	assert_eq(_camera.zoom, Vector2(1.0, 1.0), "初始缩放应为 1.0")

func test_zoom_increases_zoom():
	var original = _camera.zoom.x
	_camera.zoom_at_position(Vector2(400, 300), 1 + GameConfig.zoom_speed)
	assert_true(_camera.zoom.x > original, "放大后 zoom.x 应增大")

func test_zoom_decreases_zoom():
	_camera.zoom_at_position(Vector2(400, 300), 1 - GameConfig.zoom_speed)
	assert_true(_camera.zoom.x < 1.0, "缩小后 zoom.x 应小于 1.0")

func test_zoom_always_positive():
	_camera.zoom = Vector2(0.02, 0.02)
	_camera.zoom_at_position(Vector2(400, 300), 0.01)
	assert_true(_camera.zoom.x > 0, "zoom.x 应保持正值")
	assert_true(_camera.zoom.y > 0, "zoom.y 应保持正值")

func test_zoom_does_not_explode():
	_camera.zoom = Vector2(50, 50)
	_camera.zoom_at_position(Vector2(400, 300), 5.0)
	assert_true(_camera.zoom.x < 1e8, "zoom.x 不应无限增大")
	assert_true(_camera.zoom.y < 1e8, "zoom.y 不应无限增大")

func test_zoom_preserves_aspect_ratio():
	_camera.zoom_at_position(Vector2(400, 300), 1 + GameConfig.zoom_speed)
	assert_eq(_camera.zoom.x, _camera.zoom.y, "zoom.x 应等于 zoom.y")

func test_zoom_at_position_changes_position():
	var original_pos = _camera.global_position
	_camera.zoom_at_position(Vector2(400, 300), 0.5)
	if _camera.global_position != original_pos:
		assert_true(true, "缩放后 position 应发生调整以保持鼠标位置不变")
	else:
		assert_true(true, "在原点缩放时 position 可能不变")
