class_name InventorySlot
extends Control

@onready var background: Panel = $Background
@onready var icon_texture_rect: TextureRect = $IconTextureRect
@onready var key_label: Label = $KeyLabel
@onready var selection_border: Panel = $SelectionBorder

var _type_data: BuildingTypeData
var _slot_index: int

func setup_slot(index: int, type_data: BuildingTypeData) -> void:
	_slot_index = index
	_type_data = type_data
	key_label.text = str((index + 1) % 10)
	if type_data:
		icon_texture_rect.texture = type_data.icon_texture

func set_selected(selected: bool) -> void:
	selection_border.visible = selected
