extends Control

@onready var btn_start: Button = $VBoxContainer/btn_start
@onready var btn_settings: Button = $VBoxContainer/btn_settings

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
