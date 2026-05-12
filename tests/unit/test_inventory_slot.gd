extends GutTest

const SLOT_SCENE := preload("res://scenes/inventory_slot.tscn")

var _slot: InventorySlot = null

func before_each():
	_slot = SLOT_SCENE.instantiate()
	add_child_autoqfree(_slot)

func test_initial_state():
	assert_false(_slot.find_child("SelectionBorder", true, false).visible, "初始 selection_border 应隐藏")

func test_setup_slot_key_label():
	_slot.setup_slot(0, null)
	var key_label = _slot.find_child("KeyLabel", true, false) as Label
	assert_eq(key_label.text, "1", "槽位 0 的 key_label 应为 '1'")

func test_setup_slot_last_key_label():
	_slot.setup_slot(9, null)
	var key_label = _slot.find_child("KeyLabel", true, false) as Label
	assert_eq(key_label.text, "0", "槽位 9 的 key_label 应为 '0'")

func test_set_selected_shows_border():
	_slot.setup_slot(0, null)
	_slot.set_selected(true)
	assert_true(_slot.find_child("SelectionBorder", true, false).visible, "set_selected(true) 应显示 border")

func test_set_selected_hides_border():
	_slot.setup_slot(0, null)
	_slot.set_selected(true)
	_slot.set_selected(false)
	assert_false(_slot.find_child("SelectionBorder", true, false).visible, "set_selected(false) 应隐藏 border")

func test_setup_slot_with_type_data():
	var type_data := BuildingTypeData.new()
	type_data.type_id = "type_01"
	type_data.display_name = "容器"
	_slot.setup_slot(0, type_data)
	var placeholder_label = _slot.find_child("PlaceholderLabel", true, false) as Label
	assert_true(placeholder_label.visible, "传入无图标的 type_data 应显示占位文本")
	assert_eq(placeholder_label.text, "占位-1", "type_01 的占位文本应为 '占位-1'")
