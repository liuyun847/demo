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
	_create_pause_overlay()
	_update_pause_state()
	EventBus.start_game_requested.connect(_on_game_started)

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
	if event.is_action_pressed("toggle_pause"):
		if not start_menu.visible and not settings_panel.visible:
			_manual_paused = not _manual_paused
			_update_pause_state()
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
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	title_ls.font_size = 48
	title_ls.font_color = Color.WHITE
	title_ls.outline_size = 3
	title_ls.outline_color = Color.BLACK
	title.label_settings = title_ls
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "按空格键继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_ls := LabelSettings.new()
	hint_ls.font_size = 20
	hint_ls.font_color = Color(1, 1, 1, 0.7)
	hint_ls.outline_size = 2
	hint_ls.outline_color = Color.BLACK
	hint.label_settings = hint_ls
	vbox.add_child(hint)

	_pause_overlay.visible = false
	$UIOverlay.add_child(_pause_overlay)

func _update_pause_state() -> void:
	var should_pause := _menu_paused or _manual_paused
	get_tree().paused = should_pause
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
