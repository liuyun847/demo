extends Node

signal building_placed(grid_pos: Vector2i)
signal building_removed(grid_pos: Vector2i)
signal buildings_loaded
signal keybind_changed(action: String)

# UI 叠加层状态信号
signal start_game_requested
signal show_start_menu_requested
signal show_settings_requested

# 游戏数值设置变更信号
signal game_settings_changed

signal selection_changed(selected_cells: Array[Vector2i])
signal paste_mode_changed(active: bool)

# 流体系统信号
signal fluid_updated

# 建筑悬停提示信号
signal building_hovered(grid_pos: Vector2i, node: Node2D)
signal building_hover_exited(grid_pos: Vector2i)
