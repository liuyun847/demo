extends Control

@onready var btn_start: Button = $VBoxContainer/btn_start
@onready var btn_settings: Button = $VBoxContainer/btn_settings
@onready var btn_quit: Button = $VBoxContainer/btn_quit

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		EventBus.start_game_requested.emit()
		get_viewport().set_input_as_handled()

func _on_start_pressed() -> void:
	EventBus.start_game_requested.emit()

func _on_settings_pressed() -> void:
	EventBus.show_settings_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
