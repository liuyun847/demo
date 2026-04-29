class_name InventoryBar
extends HBoxContainer

signal slot_selected(index: int, type_id: String)

const SLOT_SCENE := preload("res://scenes/inventory_slot.tscn")
const MAX_BUILDING_TYPES := 10

var current_slot_index: int = 0
var building_types: Array[BuildingTypeData] = []

func _ready() -> void:
	_init_default_types()
	_setup_slots()
	select_slot(0)

func _init_default_types() -> void:
	for i in range(1, MAX_BUILDING_TYPES + 1):
		var data := BuildingTypeData.new()
		data.type_id = "type_%02d" % i
		data.display_name = "建筑 %d" % i
		var tex_path := "res://resources/buildings/building_%02d.svg" % i
		if ResourceLoader.exists(tex_path):
			data.icon_texture = load(tex_path)
		data.building_color = Color.from_hsv(float(i - 1) / float(MAX_BUILDING_TYPES), 0.7, 0.9)
		building_types.append(data)

func _setup_slots() -> void:
	for i in range(building_types.size()):
		var slot := SLOT_SCENE.instantiate() as InventorySlot
		add_child(slot)
		slot.setup_slot(i, building_types[i])

func select_slot(index: int) -> void:
	if index < 0 or index >= get_child_count():
		return
	var old_slot := get_child(current_slot_index) as InventorySlot
	if old_slot:
		old_slot.set_selected(false)
	current_slot_index = index
	var new_slot := get_child(current_slot_index) as InventorySlot
	if new_slot:
		new_slot.set_selected(true)
	var type_id := "default"
	if current_slot_index < building_types.size():
		type_id = building_types[current_slot_index].type_id
	slot_selected.emit(current_slot_index, type_id)

func get_current_building_type() -> String:
	if current_slot_index >= 0 and current_slot_index < building_types.size():
		return building_types[current_slot_index].type_id
	return "default"
