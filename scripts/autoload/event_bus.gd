extends Node

@warning_ignore("unused_signal")
signal building_placed(grid_pos: Vector2i)
@warning_ignore("unused_signal")
signal building_removed(grid_pos: Vector2i)
@warning_ignore("unused_signal")
signal buildings_loaded
@warning_ignore("unused_signal")
signal keybind_changed(action: String)
@warning_ignore("unused_signal")
signal keybinds_reset

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
## 元素移动信号：滑动/搬移时用单信号替代 removed+spawned 两次发射，
## 密集滑动场景（如无源水体逐 tick 下滑）可显著降低信号分发开销
@warning_ignore("unused_signal")
signal element_moved(from_grid_pos: Vector2i, to_grid_pos: Vector2i, element_type_id: String)

# 源质系统信号
@warning_ignore("unused_signal")
signal essence_threshold_reached(threshold: float, unlocks: Dictionary)

# 暂停状态变更信号
@warning_ignore("unused_signal")
signal pause_state_changed(paused: bool)

# 物品流模拟信号：每个完整 tick 完成后发射事件数组（渲染层做位置插值）
@warning_ignore("unused_signal")
signal sim_tick_completed(events: Array)

# 机器配置变更信号（分流器按方向过滤条件，触发延迟保存）
@warning_ignore("unused_signal")
signal machine_config_changed(grid_pos: Vector2i)

# 配置面板开关信号（分流器配置面板）
@warning_ignore("unused_signal")
signal config_panel_opened
@warning_ignore("unused_signal")
signal config_panel_closed
