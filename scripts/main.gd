extends Node2D

const SLOT_KEYS := [
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_5",
	"slot_6", "slot_7", "slot_8", "slot_9", "slot_0"
]

@onready var start_menu: Control = $UIOverlay/StartMenu
@onready var settings_panel: Control = $UIOverlay/SettingsPanel
@onready var inventory_bar: InventoryBar = $UIOverlay/InventoryBar

func _enter_tree() -> void:
	EventBus.buildings_loaded.connect(_on_buildings_loaded)
	EventBus.start_game_requested.connect(_on_start_game_requested)
	EventBus.show_start_menu_requested.connect(_on_show_start_menu_requested)
	EventBus.show_settings_requested.connect(_on_show_settings_requested)

func _ready() -> void:
	_hide_all_uis()
	_pause_game(false)

func _exit_tree() -> void:
	EventBus.buildings_loaded.disconnect(_on_buildings_loaded)
	EventBus.start_game_requested.disconnect(_on_start_game_requested)
	EventBus.show_start_menu_requested.disconnect(_on_show_start_menu_requested)
	EventBus.show_settings_requested.disconnect(_on_show_settings_requested)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		show_start_menu()
		return
	for i in SLOT_KEYS.size():
		if event.is_action_pressed(SLOT_KEYS[i]):
			inventory_bar.select_slot(i)
			return

func _hide_all_uis() -> void:
	start_menu.hide()
	settings_panel.hide()
	inventory_bar.hide()

func _on_buildings_loaded() -> void:
	call_deferred("show_start_menu")

func _on_start_game_requested() -> void:
	hide_start_menu()

func _on_show_start_menu_requested() -> void:
	show_start_menu()

func _on_show_settings_requested() -> void:
	show_settings()

func _pause_game(paused: bool) -> void:
	get_tree().paused = paused

func show_start_menu() -> void:
	settings_panel.hide()
	start_menu.show()
	inventory_bar.hide()
	_pause_game(true)

func hide_start_menu() -> void:
	start_menu.hide()
	inventory_bar.show()
	_pause_game(false)

func show_settings() -> void:
	start_menu.hide()
	settings_panel.show()
	inventory_bar.hide()
	_pause_game(true)
