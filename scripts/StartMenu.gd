extends Control

@onready var btn_start: Button = $VBoxContainer/btn_start
@onready var btn_settings: Button = $VBoxContainer/btn_settings
@onready var btn_quit: Button = $VBoxContainer/btn_quit

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	SceneManager.change_scene(ScenePaths.MAIN)

func _on_settings_pressed() -> void:
	SceneManager.change_scene(ScenePaths.SETTINGS)

func _on_quit_pressed() -> void:
	get_tree().quit()
