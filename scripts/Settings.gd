extends Control

@onready var btn_back: Button = $btn_back

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
	if err != OK:
		push_error("切换到开始菜单场景失败，错误码: %d" % err)
