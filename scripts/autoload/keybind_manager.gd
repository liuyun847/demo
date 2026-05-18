extends Node

const KEYBIND_VERSION: String = "1.0.0"

const ACTION_DISPLAY_NAMES: Dictionary = {
	"move_up": "上移",
	"move_down": "下移",
	"move_left": "左移",
	"move_right": "右移",
	"speed_up": "加速",
	"zoom_in": "放大",
	"zoom_out": "缩小",
	"place_building": "放置建筑",
	"remove_building": "删除建筑",
	"toggle_place_mode": "切换模式",
	"ui_copy": "复制",
	"ui_cut": "剪切",
	"ui_paste": "粘贴",
	"ui_undo": "撤销",
	"ui_redo": "重做",
	"rotate_clipboard": "旋转/切换",
}

const COMBO_MODIFIER: Dictionary = {
	"ui_copy": "Ctrl",
	"ui_cut": "Ctrl",
	"ui_paste": "Ctrl",
	"ui_undo": "Ctrl",
	"ui_redo": "Ctrl",
}

const GAMEPLAY_ACTIONS: Array[String] = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"speed_up",
	"zoom_in",
	"zoom_out",
	"place_building",
	"remove_building",
	"toggle_place_mode",
	"rotate_clipboard",
	"ui_copy",
	"ui_cut",
	"ui_paste",
	"ui_undo",
	"ui_redo",
]

func _ready() -> void:
	if not InputMap.has_action("rotate_clipboard"):
		InputMap.add_action("rotate_clipboard")
		var r_key := InputEventKey.new()
		r_key.keycode = KEY_R
		InputMap.action_add_event("rotate_clipboard", r_key)
	load_keybindings()

func get_action_display_name(action: String) -> String:
	if ACTION_DISPLAY_NAMES.has(action):
		return ACTION_DISPLAY_NAMES[action]
	return action

func get_action_combo_modifier(action: String) -> String:
	return COMBO_MODIFIER.get(action, "")

func get_event_display_text(event: InputEvent, include_modifiers: bool = true) -> String:
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			return "Shift"
		if event.keycode == KEY_CTRL:
			return "Ctrl"
		if event.keycode == KEY_ALT:
			return "Alt"
		if event.keycode == KEY_META:
			return "Meta"

		if include_modifiers:
			var parts: PackedStringArray = []
			if event.ctrl_pressed:
				parts.append("Ctrl")
			if event.shift_pressed:
				parts.append("Shift")
			if event.alt_pressed:
				parts.append("Alt")
			if event.meta_pressed:
				parts.append("Meta")
			var key_text: String = OS.get_keycode_string(event.keycode)
			if key_text.is_empty():
				key_text = OS.get_keycode_string(event.physical_keycode)
			parts.append(key_text)
			return " + ".join(parts)
		else:
			var text: String = OS.get_keycode_string(event.keycode)
			if text.is_empty():
				text = OS.get_keycode_string(event.physical_keycode)
			return text
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				return "鼠标左键"
			MOUSE_BUTTON_RIGHT:
				return "鼠标右键"
			MOUSE_BUTTON_MIDDLE:
				return "鼠标中键"
			MOUSE_BUTTON_WHEEL_UP:
				return "滚轮上"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "滚轮下"
			_:
				return "鼠标键%d" % event.button_index
	elif event is InputEventJoypadButton:
		return "手柄键%d" % event.button_index
	elif event is InputEventJoypadMotion:
		var axis_name: String = "轴%d" % event.axis
		if event.axis_value > 0:
			axis_name += "+"
		else:
			axis_name += "-"
		return axis_name
	return "未知"

func get_keybind_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var display_name: String = get_action_display_name(action)
		var modifier_prefix: String = COMBO_MODIFIER.get(action, "")
		var event_text: String = ""
		if events.size() > 0:
			if not modifier_prefix.is_empty():
				event_text = get_event_display_text(events[0], false)
			else:
				event_text = get_event_display_text(events[0])
		result.append({
			"action": action,
			"display_name": display_name,
			"event_text": event_text,
			"modifier_prefix": modifier_prefix,
		})
	return result

func remap_action(action: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		push_error("KeybindManager: 未知的动作: %s" % action)
		return

	for existing_action in GAMEPLAY_ACTIONS:
		if existing_action == action:
			continue
		var existing_events: Array[InputEvent] = InputMap.action_get_events(existing_action)
		for ev in existing_events:
			if _events_equal(ev, new_event):
				push_error("KeybindManager: 按键 %s 已被「%s」使用" % [get_event_display_text(new_event), get_action_display_name(existing_action)])
				return

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)
	save_keybindings()
	EventBus.keybind_changed.emit(action)

func reset_to_defaults() -> void:
	_apply_default_keybindings()
	save_keybindings()
	EventBus.keybind_changed.emit("")

func save_keybindings() -> void:
	var keybind_data := {
		"version": KEYBIND_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"keybindings": {},
	}

	for action in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		# 设计意图：每个动作只保存第一个按键绑定
		# 整个系统采用"一个动作一个按键"的简化设计
		# remap_action() 和 _apply_default_keybindings() 均只设置单个事件
		if events.size() > 0:
			keybind_data.keybindings[action] = [_serialize_event(events[0])]

	var dir_path := GameConfig.keybind_file_path.get_base_dir()
	var dir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK:
		push_error("KeybindManager: 无法创建按键配置目录: %s (错误码: %d)" % [dir_path, dir_err])
		return

	var file := FileAccess.open(GameConfig.keybind_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(keybind_data, "\t"))
		file.close()
	else:
		push_error("KeybindManager: 无法写入按键配置文件: %s" % GameConfig.keybind_file_path)

func load_keybindings() -> void:
	if not FileAccess.file_exists(GameConfig.keybind_file_path):
		return

	var file := FileAccess.open(GameConfig.keybind_file_path, FileAccess.READ)
	if not file:
		push_error("KeybindManager: 无法读取按键配置文件: %s" % GameConfig.keybind_file_path)
		return

	var content := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(content)
	if data == null or not data is Dictionary:
		push_error("KeybindManager: 按键配置格式无效")
		return

	if not data.has("version"):
		push_error("KeybindManager: 按键配置缺少版本号")
		return

	if str(data.version) != KEYBIND_VERSION:
		push_warning("KeybindManager: 按键配置版本不匹配，期望 %s，实际 %s，回退默认值" % [KEYBIND_VERSION, data.version])
		_apply_default_keybindings()
		return

	if not data.has("keybindings") or not data.keybindings is Dictionary:
		push_error("KeybindManager: 按键配置缺少 keybindings 字段")
		return

	for action in data.keybindings.keys():
		if not InputMap.has_action(action):
			push_warning("KeybindManager: 忽略未知动作: %s" % action)
			continue
		var raw = data.keybindings[action]
		InputMap.action_erase_events(action)

		var event_datas: Array = []
		if raw is Array:
			event_datas = raw
		elif raw is Dictionary:
			event_datas = [raw]
		else:
			continue

		for ev_data in event_datas:
			var event: InputEvent = _deserialize_event(ev_data)
			if event:
				InputMap.action_add_event(action, event)

func _apply_default_keybindings() -> void:
	var defaults: Dictionary = {
		"move_up": _create_key_event(KEY_W),
		"move_down": _create_key_event(KEY_S),
		"move_left": _create_key_event(KEY_A),
		"move_right": _create_key_event(KEY_D),
		"speed_up": _create_key_event(KEY_SHIFT),
		"zoom_in": _create_mouse_event(MOUSE_BUTTON_WHEEL_UP),
		"zoom_out": _create_mouse_event(MOUSE_BUTTON_WHEEL_DOWN),
		"place_building": _create_mouse_event(MOUSE_BUTTON_LEFT),
		"remove_building": _create_mouse_event(MOUSE_BUTTON_RIGHT),
		"toggle_place_mode": _create_key_event(KEY_E),
		"ui_copy": _create_key_event_with_ctrl(KEY_C),
		"ui_cut": _create_key_event_with_ctrl(KEY_X),
		"ui_paste": _create_key_event_with_ctrl(KEY_V),
		"ui_undo": _create_key_event_with_ctrl(KEY_Z),
		"ui_redo": _create_key_event_with_ctrl(KEY_Y),
		"rotate_clipboard": _create_key_event(KEY_R),
	}

	for action in defaults.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, defaults[action])

func _create_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.alt_pressed = false
	event.shift_pressed = false
	event.ctrl_pressed = false
	event.meta_pressed = false
	return event

func _create_key_event_with_ctrl(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.alt_pressed = false
	event.shift_pressed = false
	event.ctrl_pressed = true
	event.meta_pressed = false
	return event

func _create_mouse_event(button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
			"alt_pressed": event.alt_pressed,
			"shift_pressed": event.shift_pressed,
			"ctrl_pressed": event.ctrl_pressed,
			"meta_pressed": event.meta_pressed,
		}
	elif event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": event.button_index,
		}
	elif event is InputEventJoypadButton:
		return {
			"type": "joypad_button",
			"button_index": event.button_index,
			"device": event.device,
		}
	elif event is InputEventJoypadMotion:
		return {
			"type": "joypad_motion",
			"axis": event.axis,
			"axis_value": event.axis_value,
			"device": event.device,
		}
	return {"type": "unknown"}

func _deserialize_event(data) -> InputEvent:
	if not data is Dictionary:
		return null
	var type: String = data.get("type", "")
	match type:
		"key":
			var event := InputEventKey.new()
			event.keycode = data.get("keycode", 0) as Key
			event.physical_keycode = data.get("physical_keycode", 0) as Key
			event.alt_pressed = data.get("alt_pressed", false)
			event.shift_pressed = data.get("shift_pressed", false)
			event.ctrl_pressed = data.get("ctrl_pressed", false)
			event.meta_pressed = data.get("meta_pressed", false)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = data.get("button_index", 0) as MouseButton
			return event
		"joypad_button":
			var event := InputEventJoypadButton.new()
			event.button_index = data.get("button_index", 0) as JoyButton
			event.device = data.get("device", 0)
			return event
		"joypad_motion":
			var event := InputEventJoypadMotion.new()
			event.axis = data.get("axis", 0) as JoyAxis
			event.axis_value = data.get("axis_value", 0.0)
			event.device = data.get("device", 0)
			return event
	return null

func _events_equal(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var key_match: bool = (a.keycode != KEY_NONE and a.keycode == b.keycode) or (a.physical_keycode != KEY_NONE and a.physical_keycode == b.physical_keycode)
		if not key_match:
			return false
		return a.alt_pressed == b.alt_pressed and \
			a.shift_pressed == b.shift_pressed and \
			a.ctrl_pressed == b.ctrl_pressed and \
			a.meta_pressed == b.meta_pressed
	elif a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	elif a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index and a.device == b.device
	elif a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and sign(a.axis_value) == sign(b.axis_value) and a.device == b.device
	return false
