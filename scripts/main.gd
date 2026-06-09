extends Node2D

const SLOT_KEYS := [
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_5",
	"slot_6", "slot_7", "slot_8", "slot_9", "slot_0"
]

@onready var start_menu: Control = $UIOverlay/StartMenu
@onready var settings_panel: Control = $UIOverlay/SettingsPanel
@onready var inventory_bar: InventoryBar = $UIOverlay/InventoryBar
@onready var key_hints: VBoxContainer = $UIOverlay/KeyHints

var _manual_paused: bool = false
var _menu_paused: bool = false
var _pause_overlay: Control

func _assert_ui_ready() -> bool:
	var all_ready := true
	if start_menu == null:
		push_error("main.gd: StartMenu 节点未找到")
		all_ready = false
	if settings_panel == null:
		push_error("main.gd: SettingsPanel 节点未找到")
		all_ready = false
	if inventory_bar == null:
		push_error("main.gd: InventoryBar 节点未找到")
		all_ready = false
	if key_hints == null:
		push_error("main.gd: KeyHints 节点未找到")
		all_ready = false
	return all_ready

func _enter_tree() -> void:
	EventBus.buildings_loaded.connect(_on_buildings_loaded)
	EventBus.start_game_requested.connect(_on_start_game_requested)
	EventBus.start_game_requested.connect(_on_game_started)
	EventBus.show_start_menu_requested.connect(_on_show_start_menu_requested)
	EventBus.show_settings_requested.connect(_on_show_settings_requested)

func _ready() -> void:
	if not _assert_ui_ready():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_menu.hide()
	settings_panel.hide()
	inventory_bar.hide()
	_create_pause_overlay()
	_update_pause_state()

func _exit_tree() -> void:
	EventBus.buildings_loaded.disconnect(_on_buildings_loaded)
	EventBus.start_game_requested.disconnect(_on_start_game_requested)
	EventBus.start_game_requested.disconnect(_on_game_started)
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
	if event.is_action_pressed("toggle_pause"):
		if not start_menu.visible and not settings_panel.visible:
			_manual_paused = not _manual_paused
			_update_pause_state()
		return
	if not start_menu.visible and not settings_panel.visible:
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

func _on_game_started() -> void:
	EssencePool.set_value(GameConfig.initial_essence)
	var essence_display := EssenceDisplay.new()
	essence_display.name = "EssenceDisplay"
	essence_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	essence_display.position = Vector2(8, -8)
	$UIOverlay.add_child(essence_display)

func _on_start_game_requested() -> void:
	hide_start_menu()

func _on_show_start_menu_requested() -> void:
	show_start_menu()

func _on_show_settings_requested() -> void:
	show_settings()

func _create_pause_overlay() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = "已暂停\n（按空格键继续）"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.position = Vector2(0, 10)
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var label_ls := LabelSettings.new()
	label_ls.font_size = 18
	label_ls.font_color = Color(1, 1, 1, 0.8)
	label_ls.outline_size = 2
	label_ls.outline_color = Color.BLACK
	label.label_settings = label_ls
	_pause_overlay.add_child(label)

	_pause_overlay.visible = false
	$UIOverlay.add_child(_pause_overlay)

func _update_pause_state() -> void:
	var should_pause := _menu_paused or _manual_paused
	if _pause_overlay:
		_pause_overlay.visible = _manual_paused and not _menu_paused
	EventBus.pause_state_changed.emit(should_pause)

func show_start_menu() -> void:
	settings_panel.hide()
	key_hints.hide()
	start_menu.show()
	inventory_bar.hide()
	_menu_paused = true
	_update_pause_state()

func hide_start_menu() -> void:
	start_menu.hide()
	inventory_bar.show()
	key_hints.show()
	_menu_paused = false
	_update_pause_state()

func show_settings() -> void:
	start_menu.hide()
	key_hints.hide()
	settings_panel.show()
	inventory_bar.hide()
	_menu_paused = true
	_update_pause_state()
