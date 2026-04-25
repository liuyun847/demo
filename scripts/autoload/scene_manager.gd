extends Node

func change_scene(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("切换场景失败，目标: %s，错误码: %d" % [path, err])
