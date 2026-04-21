extends Control

@onready var btn_back: Button = $btn_back

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://start_menu.tscn")
