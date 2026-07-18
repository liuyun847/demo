extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _main: Node = null

func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child_autoqfree(_main)

func _find_node(node_name: String) -> Node:
	# owned=false 以便找到运行时动态添加（无 owner）的节点，如 PauseOverlay/EssenceDisplay
	return _main.find_child(node_name, true, false)

func test_initial_state_all_hidden() -> void:
	assert_false(_find_node("StartMenu").visible, "初始 start_menu 应隐藏")
	assert_false(_find_node("SettingsPanel").visible, "初始 settings_panel 应隐藏")
	assert_false(_find_node("InventoryBar").visible, "初始 inventory_bar 应隐藏")

func test_start_game_hides_menu_shows_bar() -> void:
	var inventory_bar: Node = _find_node("InventoryBar")
	var start_menu: Node = _find_node("StartMenu")
	EventBus.start_game_requested.emit()
	assert_false(start_menu.visible, "开始游戏后 start_menu 应隐藏")
	assert_true(inventory_bar.visible, "开始游戏后 inventory_bar 应显示")

func test_show_settings_hides_menu() -> void:
	var settings_panel: Node = _find_node("SettingsPanel")
	var start_menu: Node = _find_node("StartMenu")
	EventBus.show_settings_requested.emit()
	assert_true(settings_panel.visible, "显示设置后 settings_panel 应可见")
	assert_false(start_menu.visible, "显示设置后 start_menu 应隐藏")

func test_show_start_menu_hides_settings() -> void:
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "显示菜单后 start_menu 应可见")
	assert_false(_find_node("SettingsPanel").visible, "显示菜单后 settings_panel 应隐藏")

func test_show_start_menu_sends_pause_signal() -> void:
	watch_signals(EventBus)
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_signal_emitted(EventBus, "pause_state_changed", "显示开始菜单时应发送暂停信号")

func test_esc_toggles_start_menu() -> void:
	assert_false(_find_node("StartMenu").visible, "初始菜单隐藏")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_main._unhandled_input(event)
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "ESC 后 start_menu 应显示")


## 测试：ESC 关闭开始菜单进入主场景后，EssenceDisplay 应已存在
## 回归测试：修复 ESC 进入主场景时左上角源质数量不显示的 bug
func test_essence_display_exists_on_esc_enter_game() -> void:
	# 先显示开始菜单（模拟 _on_buildings_loaded 流程）
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "前置：start_menu 应显示")

	# 按 ESC 关闭开始菜单（不通过点击"开始游戏"按钮）
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_main._unhandled_input(event)
	await get_tree().process_frame
	assert_false(_find_node("StartMenu").visible, "ESC 后 start_menu 应关闭")

	# 验证 EssenceDisplay 已存在（_ready 中创建，与是否点击"开始游戏"无关）
	var essence_display: Node = _find_node("EssenceDisplay")
	assert_not_null(essence_display, "ESC 进入主场景后 EssenceDisplay 应存在")


## 测试：EssenceDisplay 在 _ready 阶段就已创建（无需等 start_game_requested）
func test_essence_display_created_on_ready() -> void:
	# main 在 before_each 中已 add_child，_ready 已执行
	# 先检查 PauseOverlay（也在 _ready 中创建）作为对照
	var pause_overlay: Node = _find_node("PauseOverlay")
	assert_not_null(pause_overlay, "_ready 后 PauseOverlay 应存在（对照）")
	var essence_display: Node = _find_node("EssenceDisplay")
	assert_not_null(essence_display, "_ready 后 EssenceDisplay 应立即存在")


func test_slot_keys_select_inventory() -> void:
	var bar: InventoryBar = _find_node("InventoryBar")
	EventBus.start_game_requested.emit()
	assert_true(bar.visible, "开始游戏后 inventory_bar 应显示")
	bar.select_slot(0)
	assert_true(bar.has_building_type_selected(), "选中后应有选中槽位")
	assert_eq(bar.get_current_building_type(), GameConfig.PIPE_TYPE_ID, "选中的建筑类型应为管道")
