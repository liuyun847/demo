extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _main: Node = null

func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child_autoqfree(_main)

func _find_node(name: String) -> Node:
	return _main.find_child(name, true, true)

func test_initial_state_all_hidden() -> void:
	assert_false(_find_node("StartMenu").visible, "初始 start_menu 应隐藏")
	assert_false(_find_node("SettingsPanel").visible, "初始 settings_panel 应隐藏")
	assert_false(_find_node("InventoryBar").visible, "初始 inventory_bar 应隐藏")
	assert_false(get_tree().paused, "初始游戏不应暂停（等待 buildings_loaded 信号）")

func test_start_game_hides_menu_shows_bar() -> void:
	var inventory_bar = _find_node("InventoryBar")
	var start_menu = _find_node("StartMenu")
	EventBus.start_game_requested.emit()
	assert_false(start_menu.visible, "开始游戏后 start_menu 应隐藏")
	assert_true(inventory_bar.visible, "开始游戏后 inventory_bar 应显示")
	assert_false(get_tree().paused, "开始游戏后应取消暂停")

func test_show_settings_hides_menu() -> void:
	var settings_panel = _find_node("SettingsPanel")
	var start_menu = _find_node("StartMenu")
	EventBus.show_settings_requested.emit()
	assert_true(settings_panel.visible, "显示设置后 settings_panel 应可见")
	assert_false(start_menu.visible, "显示设置后 start_menu 应隐藏")

func test_show_start_menu_hides_settings() -> void:
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "显示菜单后 start_menu 应可见")
	assert_false(_find_node("SettingsPanel").visible, "显示菜单后 settings_panel 应隐藏")

func test_show_start_menu_pauses_game() -> void:
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_true(get_tree().paused, "显示开始菜单时应暂停游戏")

func test_esc_toggles_start_menu() -> void:
	assert_false(_find_node("StartMenu").visible, "初始菜单隐藏")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_main._unhandled_input(event)
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "ESC 后 start_menu 应显示")

func test_slot_keys_select_inventory() -> void:
	var bar = _find_node("InventoryBar") as InventoryBar
	EventBus.start_game_requested.emit()
	assert_true(bar.visible, "开始游戏后 inventory_bar 应显示")
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.pressed = true
	_main._unhandled_input(event)
	assert_true(bar.has_building_type_selected(), "按 1 键后应选中槽位")
