extends VBoxContainer

const MARGIN_TOP: int = 48
const MARGIN_RIGHT: int = 10
const PANEL_WIDTH: int = 180

const EDIT_ACTIONS: Array[String] = ["ui_copy", "ui_cut", "ui_paste", "ui_undo"]

var _keycap_labels: Array[Label] = []
var _toggle_key_label: Label
var _left_click_desc: Label
var _right_click_desc: Label
var _pipette_desc: Label
var _rotate_row: HBoxContainer

@onready var _inventory_bar: InventoryBar = %InventoryBar

func _ready() -> void:
	anchors_preset = PRESET_TOP_RIGHT
	offset_right = -MARGIN_RIGHT
	offset_left = offset_right - PANEL_WIDTH
	offset_top = MARGIN_TOP

	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END

	_build_edit_section()
	_build_separator()
	_build_toggle_row()
	_build_rotate_row()
	_build_click_section()

	_refresh_click_rows()

	EventBus.keybind_changed.connect(_on_keybind_changed)
	_inventory_bar.slot_selected.connect(_on_slot_selected)
	EventBus.paste_mode_changed.connect(_on_paste_mode_changed)

func _exit_tree() -> void:
	EventBus.keybind_changed.disconnect(_on_keybind_changed)
	_inventory_bar.slot_selected.disconnect(_on_slot_selected)
	EventBus.paste_mode_changed.disconnect(_on_paste_mode_changed)

func _build_edit_section() -> void:
	for action in EDIT_ACTIONS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 8)

		var key_label := _make_keycap(action)
		row.add_child(key_label)
		_keycap_labels.append(key_label)

		var desc := _make_desc(KeybindManager.get_action_display_name(action))
		row.add_child(desc)

		add_child(row)

func _build_separator() -> void:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(PANEL_WIDTH, 4)
	add_child(sep)

func _build_toggle_row() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)

	_toggle_key_label = _make_keycap("toggle_place_mode")
	row.add_child(_toggle_key_label)

	var desc := _make_desc("切换模式")
	row.add_child(desc)

	add_child(row)

func _build_rotate_row() -> void:
	_rotate_row = HBoxContainer.new()
	_rotate_row.alignment = BoxContainer.ALIGNMENT_END
	_rotate_row.add_theme_constant_override("separation", 8)

	var key_label := _make_keycap("rotate_clipboard")
	_rotate_row.add_child(key_label)

	var desc := _make_desc("旋转剪贴板")
	_rotate_row.add_child(desc)

	_rotate_row.hide()
	add_child(_rotate_row)

func _build_click_section() -> void:
	var left_row := HBoxContainer.new()
	left_row.alignment = BoxContainer.ALIGNMENT_END
	left_row.add_theme_constant_override("separation", 8)

	var left_key := _make_keycap("place_building")
	left_row.add_child(left_key)

	_left_click_desc = _make_desc("")
	left_row.add_child(_left_click_desc)
	add_child(left_row)

	var right_row := HBoxContainer.new()
	right_row.alignment = BoxContainer.ALIGNMENT_END
	right_row.add_theme_constant_override("separation", 8)

	var right_key := _make_keycap("remove_building")
	right_row.add_child(right_key)

	_right_click_desc = _make_desc("")
	right_row.add_child(_right_click_desc)
	add_child(right_row)

	var pipette_row := HBoxContainer.new()
	pipette_row.alignment = BoxContainer.ALIGNMENT_END
	pipette_row.add_theme_constant_override("separation", 8)

	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	var pipette_key := Label.new()
	pipette_key.text = KeybindManager.get_event_display_text(wheel_event)
	pipette_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pipette_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var pk_ls := LabelSettings.new()
	pk_ls.font_size = 13
	pk_ls.font_color = Color.WHITE
	pk_ls.outline_size = 2
	pk_ls.outline_color = Color.BLACK
	pipette_key.label_settings = pk_ls

	var pk_style := StyleBoxFlat.new()
	pk_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	pk_style.set_border_width_all(1)
	pk_style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	pk_style.set_corner_radius_all(4)
	pk_style.content_margin_left = 6
	pk_style.content_margin_right = 6
	pk_style.content_margin_top = 2
	pk_style.content_margin_bottom = 2
	pipette_key.add_theme_stylebox_override("normal", pk_style)

	pipette_row.add_child(pipette_key)

	_pipette_desc = _make_desc("吸取建筑")
	pipette_row.add_child(_pipette_desc)
	add_child(pipette_row)

func _make_keycap(action: String) -> Label:
	var label := Label.new()
	label.text = _get_action_text(action)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var ls := LabelSettings.new()
	ls.font_size = 13
	ls.font_color = Color.WHITE
	ls.outline_size = 2
	ls.outline_color = Color.BLACK
	label.label_settings = ls

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	label.add_theme_stylebox_override("normal", style)
	return label

func _make_desc(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var ls := LabelSettings.new()
	ls.font_size = 13
	ls.font_color = Color.WHITE
	ls.outline_size = 2
	ls.outline_color = Color.BLACK
	label.label_settings = ls
	return label

func _get_action_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events := InputMap.action_get_events(action)
	if events.size() > 0:
		return KeybindManager.get_event_display_text(events[0])
	return "?"

func _refresh_all() -> void:
	for i in EDIT_ACTIONS.size():
		if i < _keycap_labels.size():
			_keycap_labels[i].text = _get_action_text(EDIT_ACTIONS[i])
	_toggle_key_label.text = _get_action_text("toggle_place_mode")
	_refresh_click_rows()

func _refresh_click_rows() -> void:
	var mode := _get_current_mode()
	match mode:
		"paste":
			_left_click_desc.text = "粘贴"
			_right_click_desc.text = "取消粘贴"
			_rotate_row.show()
		"place":
			_left_click_desc.text = "放置"
			_right_click_desc.text = "删除"
			_rotate_row.hide()
		"select":
			_left_click_desc.text = "框选"
			_right_click_desc.text = "取消框选"
			_rotate_row.hide()

func _get_current_mode() -> String:
	if SelectionManager.is_paste_mode:
		return "paste"
	if _inventory_bar.has_building_type_selected():
		return "place"
	return "select"

func _on_keybind_changed(_action: String) -> void:
	_refresh_all()

func _on_slot_selected(_index: int, _type_id: String) -> void:
	_refresh_click_rows()

func _on_paste_mode_changed(_active: bool) -> void:
	_refresh_click_rows()
