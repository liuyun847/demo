extends Control

@onready var btn_back: Button = $btn_back

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	if FileAccess.file_exists("res://start_menu.tscn"):
		get_tree().change_scene_to_file("res://start_menu.tscn")
	else:
		push_error("开始菜单场景文件不存在")
