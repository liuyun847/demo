extends GutTest

var _bar: InventoryBar = null

func before_each():
	_bar = autoqfree(InventoryBar.new())
	_bar.name = "InventoryBar"
	add_child_autoqfree(_bar)


func test_initial_state_not_selected():
	assert_false(_bar.has_building_type_selected(), "初始不应有选中槽位")
	assert_eq(_bar.current_slot_index, -1, "初始 current_slot_index 应为 -1")

func test_select_slot():
	_bar.select_slot(0)
	assert_true(_bar.has_building_type_selected(), "选中后 has_building_type_selected 应为 true")
	assert_eq(_bar.current_slot_index, 0, "选中后 current_slot_index 应为 0")

func test_select_same_slot_deselects():
	_bar.select_slot(0)
	assert_true(_bar.has_building_type_selected(), "第一次选中后应为选中状态")
	_bar.select_slot(0)
	assert_false(_bar.has_building_type_selected(), "重复选中同一槽位应取消选择")

func test_switch_slot():
	_bar.select_slot(0)
	assert_eq(_bar.current_slot_index, 0, "首次选中槽位 0")
	_bar.select_slot(1)
	assert_eq(_bar.current_slot_index, 1, "切换后 current_slot_index 应为 1")
	assert_true(_bar.has_building_type_selected(), "切换后仍应有选中")

func test_deselect():
	_bar.select_slot(2)
	assert_true(_bar.has_building_type_selected(), "选中后应有选中")
	_bar.deselect()
	assert_false(_bar.has_building_type_selected(), "deselect 后不应有选中")
	assert_eq(_bar.current_slot_index, -1, "deselect 后 current_slot_index 应为 -1")

func test_select_out_of_range():
	_bar.select_slot(-1)
	assert_eq(_bar.current_slot_index, -1, "选中 -1 应无效")
	_bar.select_slot(999)
	assert_eq(_bar.current_slot_index, -1, "选中 999 应无效")

func test_get_current_building_type():
	_bar.select_slot(0)
	var type_id = _bar.get_current_building_type()
	assert_true(type_id.begins_with("type_"), "选中槽位应返回 type_xx 格式的类型 ID")

func test_get_current_building_type_when_none_selected():
	assert_eq(_bar.get_current_building_type(), "default", "未选中时应返回 default")

func test_slot_selected_signal_emitted():
	watch_signals(_bar)
	_bar.select_slot(0)
	assert_signal_emitted(_bar, "slot_selected", "选中槽位时应发射 slot_selected 信号")

func test_deselect_signal_emitted():
	watch_signals(_bar)
	_bar.select_slot(0)
	_bar.deselect()
	assert_signal_emitted(_bar, "slot_selected", "取消选中时应发射 slot_selected 信号")

func test_slots_created_in_ready():
	assert_eq(_bar.get_child_count(), 11, "_ready 后应有 11 个子节点（10 个槽位 + 1 个 ModeIndicator）")
