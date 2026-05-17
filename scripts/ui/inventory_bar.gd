class_name InventoryBar
extends HBoxContainer

signal slot_selected(index: int, type_id: String)

const SLOT_SCENE := preload("res://scenes/inventory_slot.tscn")
const MAX_BUILDING_TYPES := 10
const FALLBACK_TYPE_ID := "default"

var current_slot_index: int = -1
var _last_used_slot_index: int = -1
var building_types: Array[BuildingTypeData] = []

var _slots: Array[InventorySlot] = []
var _mode_indicator_panel: Panel = null
var _mode_indicator_label: Label = null
var _mode_indicator_style: StyleBoxFlat = null

func _ready() -> void:
	_create_mode_indicator()
	_init_default_types()
	_setup_slots()
	_update_mode_indicator()
	EventBus.paste_mode_changed.connect(_on_paste_mode_changed)

func _exit_tree() -> void:
	if EventBus.paste_mode_changed.is_connected(_on_paste_mode_changed):
		EventBus.paste_mode_changed.disconnect(_on_paste_mode_changed)

func _create_mode_indicator() -> void:
	var indicator: Control = Control.new()
	indicator.custom_minimum_size = Vector2(68, 64)
	indicator.name = "ModeIndicator"

	var bg: Panel = Panel.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	indicator.add_child(bg)

	var label: Label = Label.new()
	label.name = "ModeLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label_settings: LabelSettings = LabelSettings.new()
	label_settings.font_size = 14
	label_settings.font_color = Color.WHITE
	label.label_settings = label_settings
	indicator.add_child(label)

	_mode_indicator_panel = bg
	_mode_indicator_label = label

	add_child(indicator)

func _update_mode_indicator() -> void:
	if _mode_indicator_style == null:
		_mode_indicator_style = StyleBoxFlat.new()
		_mode_indicator_style.set_content_margin_all(4)
		_mode_indicator_style.set_border_width_all(3)

	if SelectionManager.is_paste_mode:
		_mode_indicator_style.bg_color = Color(0.25, 0.15, 0.02, 0.9)
		_mode_indicator_style.border_color = Color(1, 0.5, 0, 1)
		_mode_indicator_label.text = "粘贴"
	elif current_slot_index >= 0:
		_mode_indicator_style.bg_color = Color(0.05, 0.2, 0.08, 0.9)
		_mode_indicator_style.border_color = Color(0.3, 0.85, 0.3, 1)
		_mode_indicator_label.text = "放置"
	else:
		_mode_indicator_style.bg_color = Color(0.05, 0.1, 0.22, 0.9)
		_mode_indicator_style.border_color = Color(0.4, 0.65, 1, 1)
		_mode_indicator_label.text = "框选"

	_mode_indicator_panel.add_theme_stylebox_override("panel", _mode_indicator_style)

func _on_paste_mode_changed(_active: bool) -> void:
	_update_mode_indicator()

func _init_default_types() -> void:
	for i in range(1, MAX_BUILDING_TYPES + 1):
		var data: BuildingTypeData = BuildingTypeData.new()
		data.type_id = "type_%02d" % i
		if i == 1:
			data.display_name = "容器"
			var tex_path: String = "res://resources/container_icon.svg"
			if ResourceLoader.exists(tex_path):
				data.icon_texture = load(tex_path)
		elif i == 2:
			data.display_name = "管道"
			var tex_path: String = "res://resources/pipe_icon.svg"
			if ResourceLoader.exists(tex_path):
				data.icon_texture = load(tex_path)
		elif i == 3:
			data.display_name = "水源"
			var tex_path: String = "res://resources/water_source_icon.svg"
			if ResourceLoader.exists(tex_path):
				data.icon_texture = load(tex_path)
		elif i == 4:
			data.display_name = "砖块"
			var tex_path: String = "res://resources/brick_icon.svg"
			if ResourceLoader.exists(tex_path):
				data.icon_texture = load(tex_path)
		else:
			data.display_name = "占位-%d" % i
		building_types.append(data)

func _setup_slots() -> void:
	for i in range(building_types.size()):
		var slot: InventorySlot = SLOT_SCENE.instantiate() as InventorySlot
		_slots.append(slot)
		add_child(slot)
		slot.setup_slot(i, building_types[i])
		slot.clicked.connect(select_slot)

func select_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	if index == current_slot_index:
		deselect()
		return
	if current_slot_index >= 0:
		_slots[current_slot_index].set_selected(false)
	current_slot_index = index
	_slots[current_slot_index].set_selected(true)
	var type_id: String = FALLBACK_TYPE_ID
	if current_slot_index < building_types.size():
		type_id = building_types[current_slot_index].type_id
	_update_mode_indicator()
	if current_slot_index >= 0:
		_last_used_slot_index = current_slot_index
	slot_selected.emit(current_slot_index, type_id)

func deselect() -> void:
	if current_slot_index >= 0:
		_slots[current_slot_index].set_selected(false)
	current_slot_index = -1
	_update_mode_indicator()
	slot_selected.emit(-1, FALLBACK_TYPE_ID)

func has_building_type_selected() -> bool:
	return current_slot_index >= 0

func get_current_building_type() -> String:
	if current_slot_index >= 0 and current_slot_index < building_types.size():
		return building_types[current_slot_index].type_id
	return FALLBACK_TYPE_ID

func select_by_type_id(type_id: String) -> bool:
	for i in range(building_types.size()):
		if building_types[i].type_id == type_id:
			select_slot(i)
			return true
	return false

func toggle_place_mode() -> void:
	if has_building_type_selected():
		deselect()
	else:
		if _last_used_slot_index >= 0 and _last_used_slot_index < _slots.size():
			select_slot(_last_used_slot_index)
		else:
			select_slot(0)
