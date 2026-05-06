extends Control

@onready var keybind_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentHBox/LeftVBox/ScrollContainer/KeybindList
@onready var game_options_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentHBox/RightVBox/GameOptionsList
@onready var btn_reset: Button = $MarginContainer/VBoxContainer/ButtonBar/btn_reset
@onready var btn_back: Button = $MarginContainer/VBoxContainer/ButtonBar/btn_back

var listening_action: String = ""
var listening_button: Button = null

func _ready() -> void:
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	EventBus.keybind_changed.connect(_on_keybind_changed)
	_refresh_keybind_list()
	_refresh_game_options()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if listening_action.is_empty():
		if event.is_action_pressed("ui_cancel"):
			EventBus.show_start_menu_requested.emit()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		return

	if event.is_action_pressed("ui_cancel"):
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
		key_button.text = info.event_text if not info.event_text.is_empty() else "未绑定"
		key_button.custom_minimum_size = Vector2(160, 36)
		key_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var action: String = info.action
		key_button.pressed.connect(_on_key_button_pressed.bind(action, key_button))
		row.add_child(key_button)

		keybind_list.add_child(row)

func _refresh_game_options() -> void:
	for child in game_options_list.get_children():
		child.queue_free()

	game_options_list.add_child(_create_slider_option_row(
		"滚轮缩放倍率", 0.01, 0.5, 0.01, GameConfig.zoom_speed, 2, _on_zoom_speed_changed
	))
	game_options_list.add_child(_create_slider_option_row(
		"Shift加速倍率", 1.0, 10.0, 0.1, GameConfig.shift_speed_multiplier, 1, _on_shift_speed_changed
	))

func _create_slider_option_row(label_text: String, min_val: float, max_val: float, step: float, current_val: float, decimal_places: int, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 36)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = current_val
	slider.custom_minimum_size = Vector2(120, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var edit := LineEdit.new()
	var format_str := "%%.%df" % decimal_places
	edit.text = format_str % current_val
	edit.custom_minimum_size = Vector2(60, 36)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(edit)

	slider.value_changed.connect(func(value: float) -> void:
		edit.text = format_str % value
		callback.call(value)
	)
	edit.text_submitted.connect(func(text: String) -> void:
		if not text.strip_edges().is_valid_float():
			edit.text = format_str % slider.value
			return
		var val := text.to_float()
		val = clampf(val, min_val, max_val)
		slider.value = val
		edit.text = format_str % val
		callback.call(val)
	)
	edit.focus_exited.connect(func() -> void:
		var text := edit.text
		if not text.strip_edges().is_valid_float():
			edit.text = format_str % slider.value
			return
		var val := text.to_float()
		val = clampf(val, min_val, max_val)
		slider.value = val
		edit.text = format_str % val
		callback.call(val)
	)

	return row

func _on_zoom_speed_changed(value: float) -> void:
	GameConfig.zoom_speed = value
	GameConfig.save_game_settings()
	EventBus.game_settings_changed.emit()

func _on_shift_speed_changed(value: float) -> void:
	GameConfig.shift_speed_multiplier = value
	GameConfig.save_game_settings()
	EventBus.game_settings_changed.emit()

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
	var text: String = KeybindManager.get_event_display_text(events[0]) if events.size() > 0 else ""
	button.text = text if not text.is_empty() else "未绑定"

func _on_keybind_changed(action: String) -> void:
	_cancel_listening()
	_refresh_keybind_list()

func _on_reset_pressed() -> void:
	KeybindManager.reset_to_defaults()
	# 恢复游戏数值默认值
	GameConfig.zoom_speed = GameConfig.DEFAULT_ZOOM_SPEED
	GameConfig.shift_speed_multiplier = GameConfig.DEFAULT_SHIFT_SPEED_MULTIPLIER
	GameConfig.save_game_settings()
	EventBus.game_settings_changed.emit()
	_refresh_game_options()

func _on_back_pressed() -> void:
	EventBus.show_start_menu_requested.emit()
