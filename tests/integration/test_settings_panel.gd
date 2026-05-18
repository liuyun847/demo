extends GutTest

const SETTINGS_SCENE := preload("res://scenes/settings.tscn")

var _settings: Control = null

func before_each() -> void:
	_settings = SETTINGS_SCENE.instantiate()
	add_child_autoqfree(_settings)

func test_initial_refresh_creates_keybind_rows() -> void:
	var keybind_list = _settings.find_child("KeybindList", true, false)
	assert_true(keybind_list.get_child_count() > 0, "_ready 后 keybind_list 应有子节点")

func test_initial_refresh_creates_game_options() -> void:
	var game_options_list = _settings.find_child("GameOptionsList", true, false)
	assert_true(game_options_list.get_child_count() > 0, "_ready 后 game_options_list 应有子节点")

func test_reset_restores_defaults() -> void:
	GameConfig.zoom_speed = 0.5
	GameConfig.shift_speed_multiplier = 8.0
	watch_signals(EventBus)
	var btn_reset = _settings.find_child("btn_reset", true, false) as Button
	btn_reset.pressed.emit()
	assert_eq(GameConfig.zoom_speed, GameConfig.DEFAULT_ZOOM_SPEED, "重置后 zoom_speed 应恢复默认")
	assert_eq(GameConfig.shift_speed_multiplier, GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER, "重置后 shift_speed_multiplier 应恢复默认")
	assert_signal_emitted(EventBus, "game_settings_changed", "重置后应发射 game_settings_changed")

func test_key_button_starts_listening() -> void:
	var btn_reset = _settings.find_child("btn_reset", true, false) as Button
	_settings._on_key_button_pressed("move_up", btn_reset)
	assert_eq(_settings.listening_action, "move_up", "点击按键按钮后 listening_action 应被设置")
	assert_eq(_settings.listening_button, btn_reset, "点击按键按钮后 listening_button 应被设置")

func test_escape_cancels_listening() -> void:
	var btn_reset = _settings.find_child("btn_reset", true, false) as Button
	_settings._on_key_button_pressed("move_up", btn_reset)
	assert_eq(_settings.listening_action, "move_up", "应正在监听")
	var esc_event := InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true
	_settings._input(esc_event)
	assert_eq(_settings.listening_action, "", "ESC 后 listening_action 应被清除")

func test_keybind_changed_refreshes_list() -> void:
	var keybind_list = _settings.find_child("KeybindList", true, false)
	var original_count = keybind_list.get_child_count()
	EventBus.keybind_changed.emit("move_up")
	await get_tree().process_frame
	assert_eq(keybind_list.get_child_count(), original_count, "keybind_changed 后列表应刷新")
