extends Node

const KEYBIND_VERSION: String = "1.0.0"

const ACTION_CONFIGS: Dictionary = {
	"move_up": {
		"display_name": "上移",
		"default_key": KEY_W,
		"default_key_type": "key",
		"modifier": "",
	},
	"move_down": {
		"display_name": "下移",
		"default_key": KEY_S,
		"default_key_type": "key",
		"modifier": "",
	},
	"move_left": {
		"display_name": "左移",
		"default_key": KEY_A,
		"default_key_type": "key",
		"modifier": "",
	},
	"move_right": {
		"display_name": "右移",
		"default_key": KEY_D,
		"default_key_type": "key",
		"modifier": "",
	},
	"speed_up": {
		"display_name": "加速",
		"default_key": KEY_SHIFT,
		"default_key_type": "key",
		"modifier": "",
	},
	"zoom_in": {
		"display_name": "放大",
		"default_key": MOUSE_BUTTON_WHEEL_UP,
		"default_key_type": "mouse",
		"modifier": "",
	},
	"zoom_out": {
		"display_name": "缩小",
		"default_key": MOUSE_BUTTON_WHEEL_DOWN,
		"default_key_type": "mouse",
		"modifier": "",
	},
	"place_building": {
		"display_name": "放置建筑",
		"default_key": MOUSE_BUTTON_LEFT,
		"default_key_type": "mouse",
		"modifier": "",
	},
	"remove_building": {
		"display_name": "删除建筑",
		"default_key": MOUSE_BUTTON_RIGHT,
		"default_key_type": "mouse",
		"modifier": "",
	},
	"toggle_place_mode": {
		"display_name": "切换模式",
		"default_key": KEY_E,
		"default_key_type": "key",
		"modifier": "",
	},
	"ui_copy": {
		"display_name": "复制",
		"default_key": KEY_C,
		"default_key_type": "key_with_ctrl",
		"modifier": "Ctrl",
	},
	"ui_cut": {
		"display_name": "剪切",
		"default_key": KEY_X,
		"default_key_type": "key_with_ctrl",
		"modifier": "Ctrl",
	},
	"ui_paste": {
		"display_name": "粘贴",
		"default_key": KEY_V,
		"default_key_type": "key_with_ctrl",
		"modifier": "Ctrl",
	},
	"ui_undo": {
		"display_name": "撤销",
		"default_key": KEY_Z,
		"default_key_type": "key_with_ctrl",
		"modifier": "Ctrl",
	},
	"ui_redo": {
		"display_name": "重做",
		"default_key": KEY_Y,
		"default_key_type": "key_with_ctrl",
		"modifier": "Ctrl",
	},
	"rotate_clipboard": {
		"display_name": "旋转/切换",
		"default_key": KEY_R,
		"default_key_type": "key",
		"modifier": "",
	},
	"toggle_pause": {
		"display_name": "暂停",
		"default_key": KEY_SPACE,
		"default_key_type": "key",
		"modifier": "",
	},
}

static var GAMEPLAY_ACTIONS: Array[String] = []

static func _static_init() -> void:
	GAMEPLAY_ACTIONS.assign(ACTION_CONFIGS.keys())

func _ready() -> void:
	if not InputMap.has_action("rotate_clipboard"):
		InputMap.add_action("rotate_clipboard")
		var r_key := InputEventKey.new()
		r_key.keycode = KEY_R
		InputMap.action_add_event("rotate_clipboard", r_key)
	load_keybindings()

func get_action_display_name(action: String) -> String:
	var config: Dictionary = ACTION_CONFIGS.get(action, {})
	return config.get("display_name", action)

func get_action_combo_modifier(action: String) -> String:
	var config: Dictionary = ACTION_CONFIGS.get(action, {})
	return config.get("modifier", "")

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
	for action: String in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var display_name: String = get_action_display_name(action)
		var modifier_prefix: String = get_action_combo_modifier(action)
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

	for existing_action: String in GAMEPLAY_ACTIONS:
		if existing_action == action:
			continue
		var existing_events: Array[InputEvent] = InputMap.action_get_events(existing_action)
		for ev: InputEvent in existing_events:
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

	for action: String in GAMEPLAY_ACTIONS:
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

	for action: String in data.keybindings.keys():
		if not InputMap.has_action(action):
			push_warning("KeybindManager: 忽略未知动作: %s" % action)
			continue
		var raw: Variant = data.keybindings[action]
		InputMap.action_erase_events(action)

		var event_datas: Array = []
		if raw is Array:
			event_datas = raw
		elif raw is Dictionary:
			event_datas = [raw]
		else:
			continue

		for ev_data: Variant in event_datas:
			var event: InputEvent = _deserialize_event(ev_data)
			if event:
				InputMap.action_add_event(action, event)

func _apply_default_keybindings() -> void:
	for action: String in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var config: Dictionary = ACTION_CONFIGS[action]
		var event: InputEvent
		match config.get("default_key_type", "key"):
			"key":
				event = _create_key_event(config.default_key)
			"key_with_ctrl":
				event = _create_key_event_with_ctrl(config.default_key)
			"mouse":
				event = _create_mouse_event(config.default_key)
			_:
				continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)

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

func _deserialize_event(data: Variant) -> InputEvent:
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
