extends GutTest

const START_MENU_SCENE := preload("res://scenes/start_menu.tscn")

var _menu: Control = null

func before_each() -> void:
	_menu = START_MENU_SCENE.instantiate()
	add_child_autoqfree(_menu)

func test_initial_state() -> void:
	assert_not_null(_menu.find_child("btn_start", true, false), "应存在 btn_start")
	assert_not_null(_menu.find_child("btn_settings", true, false), "应存在 btn_settings")
	assert_not_null(_menu.find_child("btn_quit", true, false), "应存在 btn_quit")
	var btn_start = _menu.find_child("btn_start", true, false) as Button
	assert_eq(btn_start.text, "开始游戏", "开始按钮文本应为 '开始游戏'")

func test_start_pressed_emits_signal() -> void:
	watch_signals(EventBus)
	var btn_start = _menu.find_child("btn_start", true, false) as Button
	btn_start.pressed.emit()
	assert_signal_emitted(EventBus, "start_game_requested", "点击开始按钮应发射 start_game_requested")

func test_settings_pressed_emits_signal() -> void:
	watch_signals(EventBus)
	var btn_settings = _menu.find_child("btn_settings", true, false) as Button
	btn_settings.pressed.emit()
	assert_signal_emitted(EventBus, "show_settings_requested", "点击设置按钮应发射 show_settings_requested")

func test_show_start_menu_requested_signal() -> void:
	watch_signals(EventBus)
	EventBus.show_start_menu_requested.emit()
	assert_signal_emitted(EventBus, "show_start_menu_requested", "应能发射 show_start_menu_requested 信号")
