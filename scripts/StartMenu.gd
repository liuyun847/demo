extends Control

@onready var btn_start: Button = $VBoxContainer/btn_start
@onready var btn_settings: Button = $VBoxContainer/btn_settings

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		push_error("切换到主场景失败，错误码: %d" % err)

func _on_settings_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/settings.tscn")
	if err != OK:
		push_error("切换到设置场景失败，错误码: %d" % err)
