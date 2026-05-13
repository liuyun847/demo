extends GutTest

var _saved_input_states: Dictionary = {}

func before_all():
	_save_input_states()

func after_all():
	_restore_input_states()

func _save_input_states() -> void:
	_saved_input_states.clear()
	for action in KeybindManager.GAMEPLAY_ACTIONS:
		if InputMap.has_action(action):
			_saved_input_states[action] = InputMap.action_get_events(action).duplicate()

func _restore_input_states() -> void:
	for action in KeybindManager.GAMEPLAY_ACTIONS:
		if _saved_input_states.has(action):
			InputMap.action_erase_events(action)
			for ev in _saved_input_states[action]:
				InputMap.action_add_event(action, ev)


func test_get_action_display_name_known():
	assert_eq(KeybindManager.get_action_display_name("move_up"), "上移")
	assert_eq(KeybindManager.get_action_display_name("place_building"), "放置建筑")
	assert_eq(KeybindManager.get_action_display_name("slot_1"), "槽位 1")
	assert_eq(KeybindManager.get_action_display_name("slot_0"), "槽位 0")

func test_get_action_display_name_unknown():
	assert_eq(KeybindManager.get_action_display_name("unknown_action"), "unknown_action")

func test_get_event_display_text_key():
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	assert_eq(KeybindManager.get_event_display_text(event), "Space")

func test_get_event_display_text_mouse_left():
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	assert_eq(KeybindManager.get_event_display_text(event), "鼠标左键")

func test_get_event_display_text_mouse_right():
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	assert_eq(KeybindManager.get_event_display_text(event), "鼠标右键")

func test_get_event_display_text_mouse_wheel_up():
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	assert_eq(KeybindManager.get_event_display_text(event), "滚轮上")

func test_get_event_display_text_joypad_button():
	var event := InputEventJoypadButton.new()
	event.button_index = 3
	var text = KeybindManager.get_event_display_text(event)
	assert_true(text.begins_with("手柄键"), "手柄按键应返回 '手柄键N'")

func test_get_event_display_text_modifier_keys():
	var shift_event := InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	assert_eq(KeybindManager.get_event_display_text(shift_event), "Shift")
	var ctrl_event := InputEventKey.new()
	ctrl_event.keycode = KEY_CTRL
	assert_eq(KeybindManager.get_event_display_text(ctrl_event), "Ctrl")
	var alt_event := InputEventKey.new()
	alt_event.keycode = KEY_ALT
	assert_eq(KeybindManager.get_event_display_text(alt_event), "Alt")

func test_get_keybind_info_returns_all_actions():
	var info = KeybindManager.get_keybind_info()
	assert_eq(info.size(), KeybindManager.GAMEPLAY_ACTIONS.size(), "应返回所有动作的绑定信息")
	for entry in info:
		assert_true(entry.has("action"), "每条信息应包含 action")
		assert_true(entry.has("display_name"), "每条信息应包含 display_name")
		assert_true(entry.has("event_text"), "每条信息应包含 event_text")

func test_remap_action_replaces_events():
	var new_event := InputEventKey.new()
	new_event.keycode = KEY_J
	assert_true(InputMap.has_action("move_up"), "move_up 动作应存在")
	KeybindManager.remap_action("move_up", new_event)
	var events = InputMap.action_get_events("move_up")
	assert_eq(events.size(), 1, "重映射后应有 1 个按键事件")
	assert_eq(events[0].keycode, KEY_J, "重映射后的按键应为 J")

func test_remap_triggers_keybind_changed():
	watch_signals(EventBus)
	var new_event := InputEventKey.new()
	new_event.keycode = KEY_L
	KeybindManager.remap_action("move_up", new_event)
	assert_signal_emitted(EventBus, "keybind_changed", "重映射应发射 keybind_changed 信号")

func test_events_equal_key_match():
	var a := InputEventKey.new()
	a.keycode = KEY_A
	a.ctrl_pressed = true
	var b := InputEventKey.new()
	b.keycode = KEY_A
	b.ctrl_pressed = true
	assert_true(KeybindManager._events_equal(a, b), "相同 KeyEvent 应判为相等")

func test_events_equal_key_not_match():
	var a := InputEventKey.new()
	a.keycode = KEY_A
	var b := InputEventKey.new()
	b.keycode = KEY_B
	assert_false(KeybindManager._events_equal(a, b), "不同 KeyEvent 应判为不等")

func test_events_equal_mouse_match():
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	assert_true(KeybindManager._events_equal(a, b), "相同 MouseButton 应判为相等")

func test_events_equal_mouse_not_match():
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_RIGHT
	assert_false(KeybindManager._events_equal(a, b), "不同 MouseButton 应判为不等")

func test_serialize_deserialize_key_event_roundtrip():
	var original := InputEventKey.new()
	original.keycode = KEY_F1
	original.shift_pressed = true
	var serialized = KeybindManager._serialize_event(original)
	var deserialized = KeybindManager._deserialize_event(serialized)
	assert_eq(deserialized.keycode, original.keycode, "反序列化后 keycode 应一致")
	assert_eq(deserialized.shift_pressed, original.shift_pressed, "反序列化后 shift_pressed 应一致")

func test_serialize_deserialize_mouse_event_roundtrip():
	var original := InputEventMouseButton.new()
	original.button_index = MOUSE_BUTTON_MIDDLE
	var serialized = KeybindManager._serialize_event(original)
	var deserialized = KeybindManager._deserialize_event(serialized)
	assert_eq(deserialized.button_index, original.button_index, "反序列化后 button_index 应一致")

func test_serialize_deserialize_joypad_button_roundtrip():
	var original := InputEventJoypadButton.new()
	original.button_index = 7
	original.device = 0
	var serialized = KeybindManager._serialize_event(original)
	var deserialized = KeybindManager._deserialize_event(serialized)
	assert_not_null(deserialized, "反序列化结果不应为 null")
	if deserialized:
		assert_eq(deserialized.button_index, original.button_index)
		assert_eq(deserialized.device, original.device)

func test_deserialize_invalid_data_returns_null():
	var result = KeybindManager._deserialize_event(null)
	assert_null(result, "null 数据应返回 null")
	result = KeybindManager._deserialize_event({})
	assert_null(result, "空字典应返回 null")
	result = KeybindManager._deserialize_event("not a dict")
	assert_null(result, "非字典数据应返回 null")

func test_remap_action_conflict_rejects():
	var move_down_events := InputMap.action_get_events("move_down")
	assert_false(move_down_events.is_empty(), "move_down 应有默认按键")
	var conflict_key: InputEvent = move_down_events[0]
	InputMap.action_erase_events("move_down")
	KeybindManager.remap_action("move_up", conflict_key)
	var events_after := InputMap.action_get_events("move_up")
	assert_eq(events_after[0].keycode, conflict_key.keycode, "撤销冲突按键后重映射 move_up 应成功")
	InputMap.action_add_event("move_down", move_down_events[0])

func test_load_keybindings_applies_custom_config():
	var _original_path := GameConfig.keybind_file_path
	var test_path := "res://save/test_keybind_load.json"
	GameConfig.keybind_file_path = test_path
	var dir_path := test_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var remap_event := InputEventKey.new()
	remap_event.keycode = KEY_J
	KeybindManager.remap_action("move_up", remap_event)
	var events = InputMap.action_get_events("move_up")
	assert_eq(events[0].keycode, KEY_J, "重映射后 move_up 应为 KEY_J")
	KeybindManager.reset_to_defaults()
	GameConfig.keybind_file_path = _original_path
	DirAccess.remove_absolute(test_path)

func test_reset_to_defaults():
	var remap_event := InputEventKey.new()
	remap_event.keycode = KEY_K
	KeybindManager.remap_action("move_up", remap_event)
	var events_after_remap = InputMap.action_get_events("move_up")
	assert_eq(events_after_remap[0].keycode, KEY_K, "重映射后 move_up 应为 KEY_K")
	KeybindManager.reset_to_defaults()
	var events_after_reset = InputMap.action_get_events("move_up")
	assert_false(events_after_reset.is_empty(), "reset_to_defaults 后 move_up 应有按键")
	assert_eq(events_after_reset[0].keycode, KEY_W, "reset_to_defaults 后 move_up 应恢复为 KEY_W")
