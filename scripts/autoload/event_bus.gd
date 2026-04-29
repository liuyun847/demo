extends Node

signal building_placed(grid_pos: Vector2i)
signal building_removed(grid_pos: Vector2i)
signal buildings_loaded
signal keybind_changed(action: String)

# UI 叠加层状态信号
signal start_game_requested
signal show_start_menu_requested
signal show_settings_requested
