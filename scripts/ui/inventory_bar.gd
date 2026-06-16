class_name InventoryBar
extends HBoxContainer

signal slot_selected(index: int, type_id: String)

const SLOT_SCENE := preload("res://scenes/inventory_slot.tscn")
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
	_update_all_locks()
	EventBus.paste_mode_changed.connect(_on_paste_mode_changed)
	EventBus.essence_threshold_reached.connect(_on_threshold_reached)

func _exit_tree() -> void:
	if EventBus.paste_mode_changed.is_connected(_on_paste_mode_changed):
		EventBus.paste_mode_changed.disconnect(_on_paste_mode_changed)
	if EventBus.essence_threshold_reached.is_connected(_on_threshold_reached):
		EventBus.essence_threshold_reached.disconnect(_on_threshold_reached)

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

func _on_threshold_reached(_threshold: float, _unlocks: Dictionary) -> void:
	_update_all_locks()

func _update_all_locks() -> void:
	for i in range(_slots.size()):
		var slot: InventorySlot = _slots[i]
		if i < building_types.size():
			var type_id: String = building_types[i].type_id
			var is_empty_slot: bool = building_types[i].display_name.is_empty()
			if is_empty_slot:
				slot.set_locked(true)
			else:
				var unlocked: bool = ProgressSystem.is_building_unlocked(type_id)
				slot.set_locked(not unlocked)

func _init_default_types() -> void:
	# 用数组定义实际建筑类型，type_id 直接使用 GameConfig 常量
	var type_entries: Array[Dictionary] = [
		{"id": GameConfig.pipe_type_id,      "name": "管道",   "icon": "res://resources/pipe_icon.svg",           "is_pipe": true},
		{"id": GameConfig.emitter_type_id,   "name": "喷口",   "icon": "res://resources/emitter_water_icon.svg",  "is_emitter": true},
		{"id": GameConfig.brick_type_id,     "name": "砖块",   "icon": "res://resources/brick_icon.svg",          "is_pipe": false},
		{"id": GameConfig.collector_type_id, "name": "收集器", "icon": "res://resources/collector_icon.svg",      "is_collector": true},
	]
	for entry: Dictionary in type_entries:
		var data: BuildingTypeData = BuildingTypeData.new()
		data.type_id = entry.id
		data.display_name = entry.name
		if ResourceLoader.exists(entry.icon):
			data.icon_texture = load(entry.icon)
		data.is_pipe = entry.get("is_pipe", false)
		data.is_emitter = entry.get("is_emitter", false)
		data.is_collector = entry.get("is_collector", false)
		building_types.append(data)
	# 补齐占位锁定槽位（显示未来可解锁的建筑类型）
	for i in range(building_types.size(), 10):
		var data: BuildingTypeData = BuildingTypeData.new()
		data.type_id = ""
		data.display_name = ""
		building_types.append(data)
	# 注册到 BuildingTypeManager（业务代码通过 type_id 查询行为属性）
	BuildingTypeManager.register_all(building_types)

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
	if _slots[index].is_locked():
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
			if not ProgressSystem.is_building_unlocked(type_id):
				return false
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
