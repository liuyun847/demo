extends GutTest

func test_fps_display_initial_text():
	var fps = autoqfree(load("res://scripts/fps_display.gd").new())
	add_child_autoqfree(fps)
	assert_eq(fps.text, "FPS: --", "初始应显示 FPS: --")

func test_fps_display_updates_after_interval():
	var fps = autoqfree(load("res://scripts/fps_display.gd").new())
	add_child_autoqfree(fps)

	fps._time_elapsed = 0.0
	fps._frame_count = 0
	fps._fps = 0.0

	for i in range(31):
		fps._process(1.0 / 60.0)

	assert_ne(fps.text, "FPS: --", "经过足够时间后应更新显示")

func test_fps_display_does_not_update_too_soon():
	var fps = autoqfree(load("res://scripts/fps_display.gd").new())
	add_child_autoqfree(fps)

	fps._time_elapsed = 0.0
	fps._frame_count = 0
	fps._fps = 0.0

	for i in range(10):
		fps._process(1.0 / 60.0)

	assert_eq(fps.text, "FPS: --", "间隔不足 0.5 秒时不应更新")

func test_fps_display_calculation():
	var fps = autoqfree(load("res://scripts/fps_display.gd").new())
	add_child_autoqfree(fps)

	fps._time_elapsed = 0.0
	fps._frame_count = 0
	fps._fps = 0.0

	fps._process(0.5)

	assert_ne(fps.text, "FPS: --", "经过 0.5 秒应更新")
	assert_eq(fps._fps, 1.0 / 0.5, "FPS 计算应为 1/0.5 = 2")

func test_fps_display_resets_after_update():
	var fps = autoqfree(load("res://scripts/fps_display.gd").new())
	add_child_autoqfree(fps)

	fps._time_elapsed = 0.5
	fps._frame_count = 30

	fps._process(0.0)

	var text_after = fps.text
	assert_ne(fps._time_elapsed, 0.5, "更新后 _time_elapsed 应重置")
	assert_eq(fps._frame_count, 0, "更新后 _frame_count 应归零")
	assert_ne(text_after, "FPS: --", "应显示 FPS 数值")

func test_fps_display_structure():
	var fps = autoqfree(load("res://scripts/fps_display.gd").new())
	add_child_autoqfree(fps)
	assert_eq(fps.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "应居中显示")
	assert_eq(fps.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "应居中对齐")
