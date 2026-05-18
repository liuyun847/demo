extends GutTest

var _bar: InventoryBar = null

func before_each() -> void:
	_bar = autoqfree(InventoryBar.new())
	_bar.name = "InventoryBar"
	add_child_autoqfree(_bar)
	SelectionManager.is_paste_mode = false

func test_select_by_type_id_found() -> void:
	assert_false(_bar.has_building_type_selected(), "初始不应有选中")
	var result: bool = _bar.select_by_type_id("type_01")
	assert_true(result, "select_by_type_id 找到时应返回 true")
	assert_true(_bar.has_building_type_selected(), "选中后应有选中")
	assert_eq(_bar.current_slot_index, 0, "type_01 应对应槽位 0")

func test_select_by_type_id_not_found() -> void:
	assert_false(_bar.has_building_type_selected(), "初始不应有选中")
	var result: bool = _bar.select_by_type_id("nonexistent_type")
	assert_false(result, "select_by_type_id 未找到时应返回 false")
	assert_false(_bar.has_building_type_selected(), "未找到时不应改变选中状态")

func test_select_by_type_id_already_selected_deselects() -> void:
	_bar.select_slot(0)
	assert_true(_bar.has_building_type_selected(), "选中槽位 0 后应有选中")
	var result: bool = _bar.select_by_type_id("type_01")
	assert_true(result, "select_by_type_id 应返回 true")
	assert_false(_bar.has_building_type_selected(), "重复选中同一类型应取消选择")


func test_initial_state_not_selected() -> void:
	assert_false(_bar.has_building_type_selected(), "初始不应有选中槽位")
	assert_eq(_bar.current_slot_index, -1, "初始 current_slot_index 应为 -1")

func test_select_slot() -> void:
	_bar.select_slot(0)
	assert_true(_bar.has_building_type_selected(), "选中后 has_building_type_selected 应为 true")
	assert_eq(_bar.current_slot_index, 0, "选中后 current_slot_index 应为 0")

func test_select_same_slot_deselects() -> void:
	_bar.select_slot(0)
	assert_true(_bar.has_building_type_selected(), "第一次选中后应为选中状态")
	_bar.select_slot(0)
	assert_false(_bar.has_building_type_selected(), "重复选中同一槽位应取消选择")

func test_switch_slot() -> void:
	_bar.select_slot(0)
	assert_eq(_bar.current_slot_index, 0, "首次选中槽位 0")
	_bar.select_slot(1)
	assert_eq(_bar.current_slot_index, 1, "切换后 current_slot_index 应为 1")
	assert_true(_bar.has_building_type_selected(), "切换后仍应有选中")

func test_deselect() -> void:
	_bar.select_slot(2)
	assert_true(_bar.has_building_type_selected(), "选中后应有选中")
	_bar.deselect()
	assert_false(_bar.has_building_type_selected(), "deselect 后不应有选中")
	assert_eq(_bar.current_slot_index, -1, "deselect 后 current_slot_index 应为 -1")

func test_select_out_of_range() -> void:
	_bar.select_slot(-1)
	assert_eq(_bar.current_slot_index, -1, "选中 -1 应无效")
	_bar.select_slot(999)
	assert_eq(_bar.current_slot_index, -1, "选中 999 应无效")

func test_get_current_building_type() -> void:
	_bar.select_slot(0)
	var type_id = _bar.get_current_building_type()
	assert_true(type_id.begins_with("type_"), "选中槽位应返回 type_xx 格式的类型 ID")

func test_get_current_building_type_when_none_selected() -> void:
	assert_eq(_bar.get_current_building_type(), "default", "未选中时应返回 default")

func test_slot_selected_signal_emitted() -> void:
	watch_signals(_bar)
	_bar.select_slot(0)
	assert_signal_emitted(_bar, "slot_selected", "选中槽位时应发射 slot_selected 信号")

func test_deselect_signal_emitted() -> void:
	watch_signals(_bar)
	_bar.select_slot(0)
	_bar.deselect()
	assert_signal_emitted(_bar, "slot_selected", "取消选中时应发射 slot_selected 信号")

func test_slots_created_in_ready() -> void:
	var slot_count := 0
	for child in _bar.get_children():
		if child is InventorySlot:
			slot_count += 1
	assert_eq(slot_count, 10, "_ready 后应有 10 个 InventorySlot 子节点")

func test_mode_indicator_exists() -> void:
	var indicator := _bar.find_child("ModeIndicator", true, false)
	assert_not_null(indicator, "_ready 后应存在 ModeIndicator 子节点")
	assert_true(indicator is Control, "ModeIndicator 应为 Control 类型")

func test_mode_indicator_text_placement() -> void:
	var indicator := _bar.find_child("ModeIndicator", true, false)
	assert_not_null(indicator, "ModeIndicator 不应为空")
	var label := indicator.find_child("ModeLabel", true, false) as Label
	assert_not_null(label, "ModeLabel 不应为空")
	_bar.select_slot(0)
	assert_eq(label.text, "放置", "选中槽位后模式指示器文本应为'放置'")

func test_mode_indicator_text_selection() -> void:
	var indicator := _bar.find_child("ModeIndicator", true, false)
	var label := indicator.find_child("ModeLabel", true, false) as Label
	_bar.select_slot(0)
	_bar.deselect()
	assert_eq(label.text, "框选", "取消选择后模式指示器文本应为'框选'")

func test_mode_indicator_text_paste() -> void:
	var indicator := _bar.find_child("ModeIndicator", true, false)
	var label := indicator.find_child("ModeLabel", true, false) as Label
	SelectionManager.is_paste_mode = true
	EventBus.paste_mode_changed.emit(true)
	assert_eq(label.text, "粘贴", "进入粘贴模式后模式指示器文本应为'粘贴'")
	SelectionManager.is_paste_mode = false

func test_toggle_place_mode_switches_between_select_and_place() -> void:
	assert_false(_bar.has_building_type_selected(), "初始应为未选中")
	_bar.toggle_place_mode()
	assert_true(_bar.has_building_type_selected(), "toggle 后应进入放置模式")
	assert_eq(_bar.current_slot_index, 0, "首次 toggle 应默认选槽位 0")
	_bar.toggle_place_mode()
	assert_false(_bar.has_building_type_selected(), "再次 toggle 应回到框选模式")

func test_toggle_place_mode_remembers_last_slot() -> void:
	_bar.select_slot(2)
	_bar.deselect()
	assert_false(_bar.has_building_type_selected(), "取消后应为框选模式")
	_bar.toggle_place_mode()
	assert_eq(_bar.current_slot_index, 2, "toggle 后应回到上次槽位 2")

func test_toggle_place_mode_last_slot_not_cleared_on_deselect() -> void:
	_bar.select_slot(1)
	_bar.select_slot(1)
	assert_false(_bar.has_building_type_selected(), "重复选相同槽位应取消选择")
	_bar.toggle_place_mode()
	assert_eq(_bar.current_slot_index, 1, "记忆不应被取消操作清除，应回到槽位 1")
