extends Node

@warning_ignore("unused_signal")
signal building_placed(grid_pos: Vector2i)
@warning_ignore("unused_signal")
signal building_removed(grid_pos: Vector2i)
@warning_ignore("unused_signal")
signal buildings_loaded
@warning_ignore("unused_signal")
signal keybind_changed(action: String)

# UI 叠加层状态信号
@warning_ignore("unused_signal")
signal start_game_requested
@warning_ignore("unused_signal")
signal show_start_menu_requested
@warning_ignore("unused_signal")
signal show_settings_requested

# 游戏数值设置变更信号
@warning_ignore("unused_signal")
signal game_settings_changed

@warning_ignore("unused_signal")
signal selection_changed(selected_cells: Array[Vector2i])
@warning_ignore("unused_signal")
signal paste_mode_changed(active: bool)

# 流体系统信号
@warning_ignore("unused_signal")
signal fluid_updated

# 建筑悬停提示信号
@warning_ignore("unused_signal")
signal building_hovered(grid_pos: Vector2i, node: Node2D)
@warning_ignore("unused_signal")
signal building_hover_exited(grid_pos: Vector2i)
