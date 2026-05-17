extends Node2D

const SLOT_KEYS := [
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_5",
	"slot_6", "slot_7", "slot_8", "slot_9", "slot_0"
]

@onready var start_menu: Control = $UIOverlay/StartMenu
@onready var settings_panel: Control = $UIOverlay/SettingsPanel
@onready var inventory_bar: InventoryBar = $UIOverlay/InventoryBar
@onready var key_hints: VBoxContainer = $UIOverlay/KeyHints

func _assert_ui_ready() -> void:
	assert(start_menu != null, "StartMenu 节点未找到")
	assert(settings_panel != null, "SettingsPanel 节点未找到")
	assert(inventory_bar != null, "InventoryBar 节点未找到")
	assert(key_hints != null, "KeyHints 节点未找到")

func _enter_tree() -> void:
	EventBus.buildings_loaded.connect(_on_buildings_loaded)
	EventBus.start_game_requested.connect(_on_start_game_requested)
	EventBus.show_start_menu_requested.connect(_on_show_start_menu_requested)
	EventBus.show_settings_requested.connect(_on_show_settings_requested)

func _ready() -> void:
	_assert_ui_ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_menu.hide()
	settings_panel.hide()
	inventory_bar.hide()
	_pause_game(false)

func _exit_tree() -> void:
	EventBus.buildings_loaded.disconnect(_on_buildings_loaded)
	EventBus.start_game_requested.disconnect(_on_start_game_requested)
	EventBus.show_start_menu_requested.disconnect(_on_show_start_menu_requested)
	EventBus.show_settings_requested.disconnect(_on_show_settings_requested)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			show_start_menu()
		elif start_menu.visible:
			hide_start_menu()
		else:
			show_start_menu()
		return
	if not get_tree().paused:
		for i in SLOT_KEYS.size():
			if event.is_action_pressed(SLOT_KEYS[i]):
				inventory_bar.select_slot(i)
				return
	if event.is_action_pressed("toggle_place_mode"):
		if SelectionManager.is_paste_mode:
			SelectionManager.cancel_paste_mode()
		elif is_instance_valid(inventory_bar):
			inventory_bar.toggle_place_mode()
		return
	if event.is_action_pressed("ui_copy"):
		SelectionManager.copy_selection()
		return
	if event.is_action_pressed("ui_cut"):
		SelectionManager.cut_selection()
		return
	if event.is_action_pressed("ui_paste"):
		SelectionManager.start_paste_mode()
		return
	if event.is_action_pressed("ui_undo"):
		SelectionManager.undo()
		return
	if event.is_action_pressed("ui_redo"):
		SelectionManager.redo()
		return
	if event.is_action_pressed("rotate_clipboard") and SelectionManager.is_paste_mode:
		SelectionManager.rotate_clipboard()
		return

func _on_buildings_loaded() -> void:
	if is_inside_tree():
		show_start_menu.call_deferred()

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
	key_hints.hide()
	start_menu.show()
	inventory_bar.hide()
	_pause_game(true)

func hide_start_menu() -> void:
	start_menu.hide()
	inventory_bar.show()
	key_hints.show()
	_pause_game(false)

func show_settings() -> void:
	start_menu.hide()
	key_hints.hide()
	settings_panel.show()
	inventory_bar.hide()
	_pause_game(true)
