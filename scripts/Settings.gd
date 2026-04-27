extends Control

@onready var keybind_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/KeybindList
@onready var btn_reset: Button = $MarginContainer/VBoxContainer/ButtonBar/btn_reset
@onready var btn_back: Button = $MarginContainer/VBoxContainer/ButtonBar/btn_back

var listening_action: String = ""
var listening_button: Button = null

func _ready() -> void:
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	EventBus.keybind_changed.connect(_on_keybind_changed)
	_refresh_keybind_list()

func _input(event: InputEvent) -> void:
	if listening_action.is_empty():
		if event.is_action_pressed("ui_cancel"):
			SceneManager.change_scene(ScenePaths.START_MENU)
		return

	if event is InputEventMouseMotion:
		return

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		_cancel_listening()
		get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		return

	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		KeybindManager.remap_action(listening_action, event)
		_stop_listening()
		get_viewport().set_input_as_handled()

func _refresh_keybind_list() -> void:
	for child in keybind_list.get_children():
		child.queue_free()

	var keybind_info: Array[Dictionary] = KeybindManager.get_keybind_info()

	for info in keybind_info:
		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = info.display_name
		name_label.custom_minimum_size = Vector2(120, 36)
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(name_label)

		var key_button := Button.new()
		var event_texts: String = "、".join(info.event_texts)
		key_button.text = event_texts if not event_texts.is_empty() else "未绑定"
		key_button.custom_minimum_size = Vector2(160, 36)
		key_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var action: String = info.action
		key_button.pressed.connect(_on_key_button_pressed.bind(action, key_button))
		row.add_child(key_button)

		keybind_list.add_child(row)

func _on_key_button_pressed(action: String, button: Button) -> void:
	if not listening_action.is_empty():
		_cancel_listening()

	listening_action = action
	listening_button = button
	button.text = "按下新按键..."

func _stop_listening() -> void:
	listening_action = ""
	listening_button = null

func _cancel_listening() -> void:
	if listening_button:
		_update_button_text(listening_action, listening_button)
	_stop_listening()

func _update_button_text(action: String, button: Button) -> void:
	if not InputMap.has_action(action):
		button.text = "未绑定"
		return
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	var texts: Array[String] = []
	for ev in events:
		texts.append(KeybindManager.get_event_display_text(ev))
	button.text = "、".join(texts) if not texts.is_empty() else "未绑定"

func _on_keybind_changed(action: String) -> void:
	if listening_action == action and listening_button:
		_update_button_text(action, listening_button)
		_stop_listening()
	_refresh_keybind_list()

func _on_reset_pressed() -> void:
	KeybindManager.reset_to_defaults()

func _on_back_pressed() -> void:
	SceneManager.change_scene(ScenePaths.START_MENU)
