class_name GridCoordinate
extends Node

func screen_to_world(camera: Camera2D, screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	var view_size := viewport.get_visible_rect().size
	var center := view_size / 2.0
	var offset := (screen_pos - center) / camera.zoom
	return offset + camera.global_position

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floor(world_pos.x / GameConfig.cell_size),
		floor(world_pos.y / GameConfig.cell_size)
	)
