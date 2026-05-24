class_name InventorySlot
extends Control

signal clicked(index: int)

@onready var background: Panel = $Background
@onready var icon_texture_rect: TextureRect = $IconTextureRect
@onready var key_label: Label = $KeyLabel
@onready var name_label: Label = $NameLabel
@onready var selection_border: Panel = $SelectionBorder
@onready var placeholder_bg: ColorRect = $PlaceholderBg
@onready var placeholder_label: Label = $PlaceholderLabel
@onready var locked_overlay: ColorRect = $LockedOverlay

var _type_data: BuildingTypeData
var _slot_index: int
var _locked: bool = false

func setup_slot(index: int, type_data: BuildingTypeData) -> void:
	_slot_index = index
	_type_data = type_data
	key_label.text = str((index + 1) % 10)
	if type_data:
		name_label.text = type_data.display_name
		if type_data.icon_texture:
			icon_texture_rect.texture = type_data.icon_texture
			icon_texture_rect.show()
			placeholder_bg.hide()
			placeholder_label.hide()
		else:
			icon_texture_rect.texture = null
			icon_texture_rect.hide()
			_setup_placeholder_visual(type_data)

func _setup_placeholder_visual(type_data: BuildingTypeData) -> void:
	var idx: int = 0
	if type_data.type_id.begins_with("type_"):
		idx = type_data.type_id.substr(5).to_int()
	placeholder_label.text = "占位-%d" % idx if idx > 0 else "占位"
	var color: Color = Color.from_hsv(float(maxi(idx - 1, 0)) / 10.0, 0.7, 0.9)
	color.a = 0.3
	placeholder_bg.color = color
	placeholder_bg.show()
	placeholder_label.show()

func set_selected(selected: bool) -> void:
	selection_border.visible = selected

func set_locked(locked: bool) -> void:
	_locked = locked
	locked_overlay.visible = locked
	if locked:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE

func is_locked() -> bool:
	return _locked

func _gui_input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(_slot_index)
		accept_event()
