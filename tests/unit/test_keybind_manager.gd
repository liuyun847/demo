extends GutTest

var _km: Node = null

func before_each() -> void:
	if _km == null:
		_km = autoqfree(load("res://scripts/autoload/keybind_manager.gd").new())
	add_child_autoqfree(_km)

func after_each() -> void:
	_km.reset_to_defaults()

func test_get_action_display_name_exists() -> void:
	assert_eq(_km.get_action_display_name("move_up"), "上移", "已有动作返回正确中文名")
	assert_eq(_km.get_action_display_name("ui_copy"), "复制", "已有动作返回正确中文名")
	assert_eq(_km.get_action_display_name("rotate_clipboard"), "旋转/切换", "已有动作返回正确中文名")

func test_get_action_display_name_not_exists() -> void:
	assert_eq(_km.get_action_display_name("unknown_action"), "unknown_action", "未知动作原样返回")

func test_get_event_display_text_key_simple() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	assert_eq(_km.get_event_display_text(event), "W", "普通按键返回键名")

func test_get_event_display_text_key_with_modifiers() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_C
	event.ctrl_pressed = true
	assert_eq(_km.get_event_display_text(event), "Ctrl + C", "组合键含修饰符前缀")

func test_get_event_display_text_mouse() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	assert_eq(_km.get_event_display_text(left), "鼠标左键", "鼠标左键")

	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	assert_eq(_km.get_event_display_text(right), "鼠标右键", "鼠标右键")

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	assert_eq(_km.get_event_display_text(wheel), "滚轮上", "滚轮上")

func test_get_keybind_info_structure() -> void:
	var info: Array[Dictionary] = _km.get_keybind_info()
	assert_true(info.size() > 0, "应有键位信息")
	var sample: Dictionary = info[0]
	assert_true(sample.has("action"), "应包含 action")
	assert_true(sample.has("display_name"), "应包含 display_name")
	assert_true(sample.has("event_text"), "应包含 event_text")
	assert_true(sample.has("modifier_prefix"), "应包含 modifier_prefix")

func test_get_keybind_info_all_actions() -> void:
	var info: Array[Dictionary] = _km.get_keybind_info()
	var actions_found: Dictionary = {}
	for entry: Dictionary in info:
		actions_found[entry.action] = true
	for action: String in _km.GAMEPLAY_ACTIONS:
		assert_true(actions_found.has(action), "所有 GAMEPLAY_ACTIONS 都应在结果中: %s" % action)

func test_remap_action_new_event() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_P
	_km.remap_action("move_up", event)
	var events: Array[InputEvent] = InputMap.action_get_events("move_up")
	assert_eq(events.size(), 1, "重映射后应有 1 个事件")
	if events.size() > 0:
		assert_eq(events[0].keycode, KEY_P, "事件键码应更新为 P")

func test_events_equal_key() -> void:
	var a := InputEventKey.new()
	a.keycode = KEY_A
	a.ctrl_pressed = true
	var b := InputEventKey.new()
	b.keycode = KEY_A
	b.ctrl_pressed = true
	assert_true(_km._events_equal(a, b), "相同键盘事件应相等")

func test_events_equal_key_different() -> void:
	var a := InputEventKey.new()
	a.keycode = KEY_A
	var b := InputEventKey.new()
	b.keycode = KEY_B
	assert_false(_km._events_equal(a, b), "不同键盘事件不应相等")

func test_events_equal_mouse() -> void:
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	assert_true(_km._events_equal(a, b), "相同鼠标事件应相等")

func test_events_equal_different_types() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_A
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	assert_false(_km._events_equal(key, mouse), "不同类型事件不应相等")

func test_serialize_deserialize_roundtrip_key() -> void:
	var original := InputEventKey.new()
	original.keycode = KEY_C
	original.ctrl_pressed = true
	original.shift_pressed = true
	var data: Dictionary = _km._serialize_event(original)
	var restored: InputEvent = _km._deserialize_event(data)
	assert_not_null(restored, "反序列化结果不应为 null")
	assert_eq(restored.keycode, KEY_C, "keycode 应一致")
	assert_true(restored.ctrl_pressed, "ctrl_pressed 应一致")
	assert_true(restored.shift_pressed, "shift_pressed 应一致")

func test_serialize_deserialize_roundtrip_mouse() -> void:
	var original := InputEventMouseButton.new()
	original.button_index = MOUSE_BUTTON_RIGHT
	var data: Dictionary = _km._serialize_event(original)
	var restored: InputEvent = _km._deserialize_event(data)
	assert_not_null(restored, "反序列化结果不应为 null")
	assert_eq(restored.button_index, MOUSE_BUTTON_RIGHT, "button_index 应一致")

func test_reset_to_defaults() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_P
	_km.remap_action("move_up", event)
	_km.reset_to_defaults()
	var events: Array[InputEvent] = InputMap.action_get_events("move_up")
	assert_eq(events.size(), 1, "重置后应有 1 个事件")
	assert_eq(events[0].keycode, KEY_W, "重置后 move_up 应恢复为 W 键")
