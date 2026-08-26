extends Node

## 地图输入处理器：放置/框选/删除/粘贴 + R 键旋转朝向 + 机器配置面板。
## 新函数式工厂语义：
## - 拖拽放置按拖拽方向自动设置建筑朝向（东/南/西/北），单格放置用 R 旋转
## - 点击已有筛选器（任意模式）打开配置面板
## - 撤销/重做捕获 direction/op_choice/filter/splitter_phase

@export var building_manager: BuildingManager = null
@export var inventory_bar: InventoryBar = null

## 幽灵预览：_ready 中从 BuildingManager 子节点解析（避免 % 唯一名在测试环境中报错）
var ghost_preview: GhostPreviewManager = null

var _state_machine: InputStateMachine = InputStateMachine.new()
var _current_type_panel: Control = null

var _last_hovered_grid: Vector2i = GameConfig.INVALID_GRID_POS
var _has_camera: bool = false
var _drag_corner_first_horizontal: bool = true
var _last_drag_grid: Vector2i = Vector2i.ZERO
## 单格放置时的建筑朝向（R 键旋转；拖拽放置由拖拽方向自动决定）
var _pending_direction: int = MachineSpec.DIR_E

## 缓存 UIOverlay 引用，避免每次输入都 get_node_or_null 查找
var _ui_overlay: CanvasLayer = null

func _ready() -> void:
	if not building_manager:
		building_manager = %BuildingManager as BuildingManager
	if not inventory_bar:
		inventory_bar = %InventoryBar as InventoryBar
	if not ghost_preview and building_manager:
		ghost_preview = building_manager.get_node_or_null("GhostPreviewManager") as GhostPreviewManager
	if ghost_preview:
		var ui_adapter: GhostUIAdapter = GhostUIAdapter.new(ghost_preview)
		_state_machine.set_ui_adapter(ui_adapter)
	if inventory_bar:
		inventory_bar.slot_selected.connect(_on_slot_selected)
	EventBus.paste_mode_changed.connect(_on_paste_mode_changed)
	_has_camera = get_viewport().get_camera_2d() != null
	_ui_overlay = get_node_or_null("../UIOverlay") as CanvasLayer

func _exit_tree() -> void:
	if EventBus.paste_mode_changed.is_connected(_on_paste_mode_changed):
		EventBus.paste_mode_changed.disconnect(_on_paste_mode_changed)
	if inventory_bar and inventory_bar.slot_selected.is_connected(_on_slot_selected):
		inventory_bar.slot_selected.disconnect(_on_slot_selected)

func _on_slot_selected(index: int, _type_id: String) -> void:
	if index < 0:
		if ghost_preview:
			ghost_preview.hide_ghost()
		_cancel_all_dragging()
		return
	_pending_direction = MachineSpec.DIR_E

func _on_paste_mode_changed(_active: bool) -> void:
	_cancel_all_dragging()

func _cancel_all_dragging() -> void:
	if is_instance_valid(_current_type_panel):
		_current_type_panel.queue_free()
		_current_type_panel = null
	if ghost_preview:
		ghost_preview.clear_paste_preview()
	_state_machine.reset()

func _get_grid_pos(event: InputEvent) -> Vector2i:
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		return Vector2i.ZERO
	return GridCoordinate.screen_to_grid(camera, event.position)

func _is_building_placement_mode() -> bool:
	return inventory_bar and inventory_bar.has_building_type_selected() and not SelectionManager.is_paste_mode

func _is_paste_mode() -> bool:
	return SelectionManager.is_paste_mode

func _is_selection_mode() -> bool:
	return not _is_building_placement_mode() and not _is_paste_mode()

func _unhandled_input(event: InputEvent) -> void:
	if _ui_overlay:
		var menu := _ui_overlay.get_node_or_null("StartMenu") as Control
		var settings := _ui_overlay.get_node_or_null("SettingsPanel") as Control
		if (menu and menu.visible) or (settings and settings.visible):
			return
	if event.is_action_pressed("rotate_clipboard") and not event.is_echo():
		# R 键：粘贴模式旋转剪贴板 / 放置模式旋转朝向 / 拖拽中切换拐角
		if _is_paste_mode():
			if SelectionManager.is_paste_mode:
				SelectionManager.rotate_clipboard()
			get_viewport().set_input_as_handled()
			return
		if _state_machine.current_state == InputStateMachine.State.DRAGGING:
			_drag_corner_first_horizontal = not _drag_corner_first_horizontal
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if start_grid != _last_drag_grid:
				var cells: Array[Vector2i] = _l_path_cells(start_grid, _last_drag_grid, _drag_corner_first_horizontal)
				var dirs: Array[int] = _dirs_for_l_path(cells)
				ghost_preview.show_ghost(cells, inventory_bar.get_current_building_type() if inventory_bar else "", dirs)
			get_viewport().set_input_as_handled()
			return
		if _is_building_placement_mode():
			_pending_direction = (_pending_direction + 1) % 4
			# 旋转后立即刷新预览箭头（鼠标静止时 motion 不会触发）
			if ghost_preview and _last_hovered_grid != GameConfig.INVALID_GRID_POS and inventory_bar:
				ghost_preview.show_ghost([_last_hovered_grid], inventory_bar.get_current_building_type(), [_pending_direction])
			get_viewport().set_input_as_handled()
			return

	if not _has_camera:
		return
	var viewport: Viewport = get_viewport()
	if not viewport.get_camera_2d():
		_has_camera = false
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event, viewport)
		return

	if not event is InputEventMouseButton:
		return

	# 滚轮上下滚均选中当前悬停建筑的类型
	if (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP) and event.pressed:
		if building_manager.has_building(_last_hovered_grid):
			var type_id: String = building_manager.get_building_type(_last_hovered_grid)
			if inventory_bar and type_id != "default":
				inventory_bar.select_by_type_id(type_id)
			viewport.set_input_as_handled()
		return

	var grid_pos: Vector2i = _get_grid_pos(event)

	if _is_paste_mode():
		_handle_paste_mode(event, grid_pos, viewport)
		return

	if _is_building_placement_mode():
		_handle_building_mode(event, grid_pos, viewport)
		return

	if _is_selection_mode():
		_handle_selection_mode(event, grid_pos, viewport)

func _handle_mouse_motion(event: InputEventMouseMotion, viewport: Viewport) -> void:
	var grid_pos: Vector2i = _get_grid_pos(event)

	if _state_machine.current_state == InputStateMachine.State.IDLE:
		if grid_pos != _last_hovered_grid:
			if building_manager.has_building(_last_hovered_grid):
				EventBus.building_hover_exited.emit(_last_hovered_grid)
			if building_manager.has_building(grid_pos):
				var node: Node = building_manager.get_building_node(grid_pos)
				if node:
					EventBus.building_hovered.emit(grid_pos, node)
			_last_hovered_grid = grid_pos

	match _state_machine.current_state:
		InputStateMachine.State.IDLE:
			if _is_paste_mode():
				SelectionManager.paste_anchor = grid_pos
				var cells: Array[Vector2i] = [grid_pos]
				ghost_preview.set_paste_preview_line(cells, SelectionManager.get_effective_clipboard())
				viewport.set_input_as_handled()
				return
			if _is_building_placement_mode() and inventory_bar:
				ghost_preview.show_ghost([grid_pos], inventory_bar.get_current_building_type(), [_pending_direction])
		InputStateMachine.State.DRAGGING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if grid_pos != start_grid:
				_last_drag_grid = grid_pos
				# 与放置共用同一有序路径（GridUtils.get_l_cells 按坐标升序，反向拖拽时方向会错）
				var cells: Array[Vector2i] = _l_path_cells(start_grid, grid_pos, _drag_corner_first_horizontal)
				var dirs: Array[int] = _dirs_for_l_path(cells)
				ghost_preview.show_ghost(cells, inventory_bar.get_current_building_type() if inventory_bar else "", dirs)
			viewport.set_input_as_handled()
		InputStateMachine.State.REMOVING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if grid_pos != start_grid:
				var cells: Array[Vector2i] = GridUtils.get_rect_cells(start_grid, grid_pos)
				ghost_preview.show_remove_ghost(cells)
			viewport.set_input_as_handled()
		InputStateMachine.State.SELECTING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if grid_pos != start_grid:
				var cells: Array[Vector2i] = GridUtils.get_rect_cells(start_grid, grid_pos)
				ghost_preview.show_select_ghost(cells)
			viewport.set_input_as_handled()
		InputStateMachine.State.DESELECTING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if grid_pos != start_grid:
				var cells: Array[Vector2i] = GridUtils.get_rect_cells(start_grid, grid_pos)
				ghost_preview.show_deselect_ghost(cells)
			viewport.set_input_as_handled()
		InputStateMachine.State.PASTE_DRAGGING:
			SelectionManager.paste_anchor = grid_pos
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			var unit_size := SelectionManager.get_effective_clipboard_unit_size()
			var anchors := GridUtils.get_paste_line_anchors(start_grid, grid_pos, unit_size.x, unit_size.y)
			ghost_preview.set_paste_preview_line(anchors, SelectionManager.get_effective_clipboard())
			viewport.set_input_as_handled()

func _handle_paste_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_state_machine.transition_to(InputStateMachine.State.PASTE_DRAGGING, {
			"start_grid": grid_pos,
			"building_manager": building_manager,
			"clipboard": SelectionManager.get_effective_clipboard(),
		})
		viewport.set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _state_machine.current_state == InputStateMachine.State.PASTE_DRAGGING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			var unit_size := SelectionManager.get_effective_clipboard_unit_size()
			var anchors := GridUtils.get_paste_line_anchors(start_grid, grid_pos, unit_size.x, unit_size.y)
			SelectionManager.perform_paste_batch(anchors)
			_state_machine.transition_to(InputStateMachine.State.IDLE)
		viewport.set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		SelectionManager.cancel_paste_mode()
		if ghost_preview:
			ghost_preview.clear_paste_preview()
		_state_machine.reset()
		viewport.set_input_as_handled()
		return

## 打开机器配置面板（筛选器）
func _open_config_panel(machine: MachineNode) -> void:
	if is_instance_valid(_current_type_panel):
		_current_type_panel.queue_free()
		_current_type_panel = null

	var kind := machine.get_kind()
	var panel := MachineConfigPanel.new()
	if kind == MachineSpec.KIND_FILTER:
		panel.mode = MachineConfigPanel.Mode.FILTER
	else:
		panel.queue_free()
		return
	panel.target = machine
	if _ui_overlay == null:
		panel.queue_free()
		return
	_ui_overlay.add_child(panel)
	_current_type_panel = panel
	EventBus.config_panel_opened.emit()

## 需要配置面板的机器
func _is_configurable_machine(node: Node) -> bool:
	return node is MachineNode and (node as MachineNode).get_kind() == MachineSpec.KIND_FILTER

## 相邻格子增量 -> 建筑朝向（零增量时归北；调用方保证 from != to，单格路径走 _pending_direction）
func _dir_between(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	if delta.x != 0:
		return MachineSpec.DIR_E if delta.x > 0 else MachineSpec.DIR_W
	return MachineSpec.DIR_S if delta.y > 0 else MachineSpec.DIR_N

## L 型路径格子（按拖拽方向 from -> corner -> to 顺序生成）。
## 注意 GridUtils.get_l_cells 按坐标升序生成（反向拖拽时顺序与拖拽方向相反），
## 朝向必须按真实拖拽方向逐格计算，故这里独立生成有序路径而非复用 get_l_cells。
func _l_path_cells(from_pos: Vector2i, to_pos: Vector2i, corner_first_horizontal: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var corner: Vector2i
	if corner_first_horizontal:
		corner = Vector2i(to_pos.x, from_pos.y)
	else:
		corner = Vector2i(from_pos.x, to_pos.y)
	# 第一段：from -> corner
	var seg1_dir := _dir_between(from_pos, corner)
	var cur := from_pos
	cells.append(cur)
	while cur != corner:
		cur += MachineSpec.dir_to_offset(seg1_dir)
		cells.append(cur)
	# 第二段：corner -> to
	var seg2_dir := _dir_between(corner, to_pos)
	while cur != to_pos:
		cur += MachineSpec.dir_to_offset(seg2_dir)
		cells.append(cur)
	return cells

## L 型路径逐格朝向：每格指向路径中下一格的方向，末格沿用最后一段方向。
## 使物品沿 L 路径流动（水平段横走、垂直段纵走、拐角转向）。
func _dirs_for_l_path(cells: Array[Vector2i]) -> Array[int]:
	var dirs: Array[int] = []
	if cells.is_empty():
		return dirs
	if cells.size() == 1:
		dirs.append(_pending_direction)
		return dirs
	for i in range(cells.size() - 1):
		dirs.append(_dir_between(cells[i], cells[i + 1]))
	dirs.append(dirs.back())
	return dirs

func _handle_building_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.is_action("place_building") and event.pressed:
		if building_manager.has_building(grid_pos):
			# 放置模式下点击已有可配置机器同样打开面板
			var node := building_manager.get_building_node(grid_pos)
			if _is_configurable_machine(node):
				_open_config_panel(node as MachineNode)
				viewport.set_input_as_handled()
				return
		var building_type: String = inventory_bar.get_current_building_type() if inventory_bar else "default"
		if not ProgressSystem.is_building_unlocked(building_type):
			return
		_state_machine.transition_to(InputStateMachine.State.DRAGGING, {
			"start_grid": grid_pos,
			"building_manager": building_manager,
			"building_type": building_type,
			"direction": _pending_direction,
		})
		viewport.set_input_as_handled()
		return

	if event.is_action("place_building") and not event.pressed and _state_machine.current_state == InputStateMachine.State.DRAGGING:
		var ctx: Dictionary = _state_machine.context
		var start_grid: Vector2i = ctx.get("start_grid", Vector2i.ZERO)
		var building_type: String = ctx.get("building_type", "default")
		# 按拖拽方向生成有序路径，逐格计算朝向（反拖/正拖均沿 from -> corner -> to）
		var cells: Array[Vector2i] = _l_path_cells(start_grid, grid_pos, _drag_corner_first_horizontal)
		var dirs: Array[int] = _dirs_for_l_path(cells)
		var placed: Dictionary = {}
		var previous: Dictionary = {}
		for i in range(cells.size()):
			var cell: Vector2i = cells[i]
			# 分流器放传送带上会转换原带格：记录原带条目，撤销时还原（而非一并删除）
			var prev_entry: Dictionary = {}
			var prev_data := building_manager.get_building_data(cell)
			if prev_data != null:
				prev_entry = BuildingDataSyncService.data_to_entry(prev_data)
			if building_manager.place_building(cell, building_type, {"direction": dirs[i]}):
				placed[cell] = {"type": building_type, "direction": dirs[i]}
				if not prev_entry.is_empty():
					previous[cell] = prev_entry
		if not placed.is_empty():
			var cmd: UndoCommand = UndoCommand.new()
			cmd.type = UndoCommand.Type.PLACE
			cmd.buildings = placed
			cmd.previous = previous
			SelectionManager.push_undo_command(cmd)
			# 放置后打开配置面板（最后放置的可配置机器）
			var last_configurable: MachineNode = null
			for cell: Vector2i in placed.keys():
				var placed_node := building_manager.get_building_node(cell)
				if _is_configurable_machine(placed_node):
					last_configurable = placed_node as MachineNode
			if last_configurable:
				_open_config_panel(last_configurable)
		_state_machine.transition_to(InputStateMachine.State.IDLE)
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and event.pressed:
		if _state_machine.current_state == InputStateMachine.State.DRAGGING:
			_state_machine.transition_to(InputStateMachine.State.IDLE)
			viewport.set_input_as_handled()
			return
		_state_machine.transition_to(InputStateMachine.State.REMOVING, {
			"start_grid": grid_pos,
			"building_manager": building_manager,
		})
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and not event.pressed and _state_machine.current_state == InputStateMachine.State.REMOVING:
		var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
		var cells: Array[Vector2i] = GridUtils.get_rect_cells(start_grid, grid_pos)
		var removed: Dictionary = {}
		for cell: Vector2i in cells:
			if building_manager.has_building(cell):
				var bdata := building_manager.get_building_data(cell)
				var entry: Dictionary = {"type": building_manager.get_building_type(cell)}
				if bdata != null:
					# 先同步节点状态到 data，避免读到 stale 数据，再统一转条目（物品流字段）
					var node := building_manager.get_building_node(cell)
					if node != null:
						BuildingDataSyncService.sync_from_node(bdata, node)
					entry = BuildingDataSyncService.data_to_entry(bdata)
				removed[cell] = entry
		building_manager.remove_buildings_in_rect(cells)
		if not removed.is_empty():
			var cmd: UndoCommand = UndoCommand.new()
			cmd.type = UndoCommand.Type.REMOVE
			cmd.buildings = removed
			SelectionManager.push_undo_command(cmd)
		_state_machine.transition_to(InputStateMachine.State.IDLE)
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and not event.pressed:
		viewport.set_input_as_handled()
		return

func _handle_selection_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.is_action("place_building") and event.pressed:
		if building_manager.has_building(grid_pos):
			var node := building_manager.get_building_node(grid_pos)
			# 点击筛选器打开配置面板
			if _is_configurable_machine(node):
				_open_config_panel(node as MachineNode)
				viewport.set_input_as_handled()
				return
		_state_machine.transition_to(InputStateMachine.State.SELECTING, {
			"start_grid": grid_pos,
			"building_manager": building_manager,
		})
		viewport.set_input_as_handled()
		return

	if event.is_action("place_building") and not event.pressed and _state_machine.current_state == InputStateMachine.State.SELECTING:
		var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
		var cells: Array[Vector2i] = GridUtils.get_rect_cells(start_grid, grid_pos)
		SelectionManager.select_rect(cells)
		_state_machine.transition_to(InputStateMachine.State.IDLE)
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and event.pressed:
		_state_machine.transition_to(InputStateMachine.State.DESELECTING, {
			"start_grid": grid_pos,
			"building_manager": building_manager,
		})
		viewport.set_input_as_handled()
		return

	if event.is_action("remove_building") and not event.pressed and _state_machine.current_state == InputStateMachine.State.DESELECTING:
		var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
		var cells: Array[Vector2i] = GridUtils.get_rect_cells(start_grid, grid_pos)
		SelectionManager.deselect_rect(cells)
		_state_machine.transition_to(InputStateMachine.State.IDLE)
		viewport.set_input_as_handled()
		return