extends GutTest

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _main: Node = null

func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child_autoqfree(_main)

func _find_node(node_name: String) -> Node:
	# owned=false 以便找到运行时动态添加（无 owner）的节点，如 PauseOverlay
	return _main.find_child(node_name, true, false)

## 打开设置面板并等待时序稳定：SaveManager._ready 会 call_deferred("load_buildings")，
## 随后 buildings_loaded → main 自动打开开始菜单（真实游戏启动流程）。若在加载完成前
## 直接 emit show_settings_requested，帧后的 buildings_loaded 回调会覆盖（重开菜单）。
## 故先等若干帧让加载完成、菜单稳定，再打开设置（模拟真实游戏中打开设置）。
func _open_settings_stable() -> void:
	for i in range(3):
		await get_tree().process_frame
	EventBus.show_settings_requested.emit()
	await get_tree().process_frame
	assert_true(_find_node("SettingsPanel").visible, "设置面板应可见（加载完成后打开）")

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


## 测试：ESC 关闭开始菜单进入主场景，物品流系统应就绪
func test_flow_systems_ready_on_enter_game() -> void:
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_main._unhandled_input(event)
	await get_tree().process_frame
	assert_false(_find_node("StartMenu").visible, "ESC 后 start_menu 应关闭")
	var bm := _find_node("BuildingManager") as BuildingManager
	assert_not_null(bm, "BuildingManager 应存在")
	assert_not_null(bm.get_flow_coordinator(), "物品流协调器应就绪")


## 测试：PauseOverlay 在 _ready 阶段就已创建（对照节点）
func test_pause_overlay_created_on_ready() -> void:
	var pause_overlay: Node = _find_node("PauseOverlay")
	assert_not_null(pause_overlay, "_ready 后 PauseOverlay 应存在")


func test_slot_keys_select_inventory() -> void:
	var bar: InventoryBar = _find_node("InventoryBar")
	EventBus.start_game_requested.emit()
	assert_true(bar.visible, "开始游戏后 inventory_bar 应显示")
	bar.select_slot(0)
	assert_true(bar.has_building_type_selected(), "选中后应有选中槽位")
	assert_eq(bar.get_current_building_type(), MachineSpec.T_BELT, "选中的建筑类型应为传送带")


## 回归：设置页按键穿透——打开设置后，世界输入（数字键切建筑/空格暂停/E 放置模式）
## 不得再响应（main._unhandled_input 应在 settings_panel 可见时直接返回）
func test_settings_open_blocks_world_shortcuts() -> void:
	EventBus.start_game_requested.emit()
	var bar: InventoryBar = _find_node("InventoryBar")
	assert_true(bar.visible, "先进入游戏")
	bar.select_slot(0)
	await _open_settings_stable()
	assert_true(_find_node("SettingsPanel").visible, "设置面板应可见")
	var selected_before: String = bar.get_current_building_type()
	# 数字键 2（切换槽位）不应穿透到世界
	var key_2 := InputEventKey.new()
	key_2.keycode = KEY_2
	key_2.pressed = true
	_main._unhandled_input(key_2)
	assert_eq(bar.get_current_building_type(), selected_before, "设置打开时按数字键不应切换建筑槽位")

## 回归：设置页打开时 ESC 由 Settings._input 处理（关闭设置回菜单），
## main._unhandled_input 不再触发菜单 toggle（避免设置页与菜单叠加）
func test_settings_open_esc_returns_to_menu() -> void:
	await _open_settings_stable()
	assert_true(_find_node("SettingsPanel").visible, "设置面板应可见")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	# 直接调用 main._unhandled_input：设置可见时 main 应不处理 ESC（Settings 面板自身负责）
	_main._unhandled_input(event)
	assert_true(_find_node("SettingsPanel").visible, "main 不应处理设置页 ESC（面板保持可见，由 Settings 关闭）")

## 回归：相机在设置打开时不响应滚轮缩放（按键穿透修复）
func test_camera_ignores_input_when_settings_open() -> void:
	await _open_settings_stable()
	var cam: Camera2D = _find_node("Camera2D")
	assert_not_null(cam, "相机应存在")
	var zoom_before: Vector2 = cam.zoom
	# 滚轮事件应被相机 _unhandled_input 守卫拦截
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	cam._unhandled_input(wheel_up)
	assert_eq(cam.zoom, zoom_before, "设置打开时滚轮不应缩放相机")

## 回归：开始菜单可见时按空格（toggle_pause）不应穿透切换手动暂停（菜单守卫只放行 ESC）
func test_start_menu_open_blocks_pause_toggle() -> void:
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "开始菜单应可见")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	_main._unhandled_input(space)
	assert_false(_main._manual_paused, "菜单打开时按空格不应切换手动暂停（未暂停时不被置位）")
	assert_true(_find_node("StartMenu").visible, "按空格后开始菜单应保持可见")
	# 完整语义：菜单打开时即便已手动暂停，按空格也不应把它切走（守卫拦截 toggle_pause）
	_main._manual_paused = true
	_main._unhandled_input(space)
	assert_true(_main._manual_paused, "菜单打开时按空格不应切走已启用的手动暂停")

## 正向闭环：设置页 ESC → Settings._input 接管（emit show_start_menu_requested）
## → 菜单打开、设置关闭。与 test_settings_open_esc_returns_to_menu 互补：后者证明
## main 不抢 ESC，本用例证明 Settings 侧处理真实生效（防止 main 守卫掩盖 Settings 失效）
func test_settings_esc_closes_settings_opens_menu() -> void:
	await _open_settings_stable()
	var settings_node: Node = _find_node("SettingsPanel")
	assert_true(settings_node.visible, "设置面板应可见")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	settings_node._input(esc)
	await get_tree().process_frame
	assert_false(_find_node("SettingsPanel").visible, "ESC 经 Settings 处理后设置面板应关闭")
	assert_true(_find_node("StartMenu").visible, "ESC 经 Settings 处理后应回到开始菜单")

## 回归：开始菜单可见时 ESC 仍应关闭菜单（菜单守卫唯一放行的世界键）
func test_start_menu_open_esc_still_closes_menu() -> void:
	EventBus.show_start_menu_requested.emit()
	await get_tree().process_frame
	assert_true(_find_node("StartMenu").visible, "开始菜单应可见")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_main._unhandled_input(esc)
	assert_false(_find_node("StartMenu").visible, "菜单打开时 ESC 应关闭菜单进入游戏")
