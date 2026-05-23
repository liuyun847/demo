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

# 摄像机变更信号
@warning_ignore("unused_signal")
signal camera_changed

# 建筑悬停提示信号
@warning_ignore("unused_signal")
signal building_hovered(grid_pos: Vector2i, node: Node2D)
@warning_ignore("unused_signal")
signal building_hover_exited(grid_pos: Vector2i)

# 元素系统信号
@warning_ignore("unused_signal")
signal element_spawned(grid_pos: Vector2i, element_type_id: String)
@warning_ignore("unused_signal")
signal element_removed(grid_pos: Vector2i, element_type_id: String)
@warning_ignore("unused_signal")
signal reaction_occurred(grid_pos: Vector2i, reactant_a_id: String, reactant_b_id: String, product_id: String)

# 源质系统信号
@warning_ignore("unused_signal")
signal essence_changed(new_value: float)
@warning_ignore("unused_signal")
signal essence_threshold_reached(threshold: float, unlocks: Dictionary)
