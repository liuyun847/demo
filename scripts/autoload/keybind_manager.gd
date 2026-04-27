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
]

func _ready() -> void:
	load_keybindings()

func get_action_display_name(action: String) -> String:
	if ACTION_DISPLAY_NAMES.has(action):
		return ACTION_DISPLAY_NAMES[action]
	return action

func get_event_display_text(event: InputEvent) -> String:
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			return "Shift"
		if event.keycode == KEY_CTRL:
			return "Ctrl"
		if event.keycode == KEY_ALT:
			return "Alt"
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
		var event_texts: Array[String] = []
		for ev in events:
			event_texts.append(get_event_display_text(ev))
		result.append({
			"action": action,
			"display_name": display_name,
			"events": events,
			"event_texts": event_texts,
		})
	return result

func remap_action(action: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		push_error("KeybindManager: 未知的动作: %s" % action)
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)
	save_keybindings()
	EventBus.keybind_changed.emit(action)

func reset_to_defaults() -> void:
	_apply_default_keybindings()
	save_keybindings()
	for action in GAMEPLAY_ACTIONS:
		EventBus.keybind_changed.emit(action)

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
		var event_list: Array = []
		for ev in events:
			event_list.append(_serialize_event(ev))
		keybind_data.keybindings[action] = event_list

	var dir_path := GameConfig.keybind_file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

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

	var data = JSON.parse_string(content)
	if data == null or not data is Dictionary:
		push_error("KeybindManager: 按键配置格式无效")
		return

	if not data.has("version"):
		push_error("KeybindManager: 按键配置缺少版本号")
		return

	if data.version != KEYBIND_VERSION:
		push_warning("KeybindManager: 按键配置版本不匹配，期望 %s，实际 %s" % [KEYBIND_VERSION, data.version])

	if not data.has("keybindings") or not data.keybindings is Dictionary:
		push_error("KeybindManager: 按键配置缺少 keybindings 字段")
		return

	for action in data.keybindings.keys():
		if not InputMap.has_action(action):
			push_warning("KeybindManager: 忽略未知动作: %s" % action)
			continue
		var event_list = data.keybindings[action]
		if not event_list is Array:
			continue
		InputMap.action_erase_events(action)
		for ev_data in event_list:
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
	}

	for action in defaults.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, defaults[action])

func _create_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
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
