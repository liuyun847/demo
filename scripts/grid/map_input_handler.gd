extends Node

@export var building_manager: BuildingManager = null
@export var inventory_bar: InventoryBar = null

@onready var ghost_preview: GhostPreviewManager = %BuildingManager/GhostPreviewManager

const ELEMENT_TYPE_PANEL_SCENE := preload("res://scenes/element_type_panel.tscn")

var _state_machine: InputStateMachine = InputStateMachine.new()
var _current_type_panel: Control = null

var _last_hovered_grid: Vector2i = GameConfig.INVALID_GRID_POS
var _has_camera: bool = false
var _drag_corner_first_horizontal: bool = true
var _last_drag_grid: Vector2i = Vector2i.ZERO

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

func _on_slot_selected(index: int, type_id: String) -> void:
	if index < 0 or not BuildingTypeManager.is_source(type_id):
		if ghost_preview:
			ghost_preview.hide_ghost()
		_cancel_all_dragging()
		return
	ghost_preview.hide_collector_ghost_range()

func _on_paste_mode_changed(_active: bool) -> void:
	if ghost_preview:
		ghost_preview.hide_collector_ghost_range()
	_cancel_all_dragging()

func _cancel_all_dragging() -> void:
	if is_instance_valid(_current_type_panel):
		_current_type_panel.queue_free()
		_current_type_panel = null
	if ghost_preview:
		ghost_preview.clear_paste_preview()
		ghost_preview.hide_collector_ghost_range()
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
		# 源头已移除方向概念，R 仅用于粘贴模式下旋转剪贴板
		if _state_machine.current_state == InputStateMachine.State.DRAGGING:
			_drag_corner_first_horizontal = not _drag_corner_first_horizontal
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if start_grid != _last_drag_grid:
				var cells: Array[Vector2i] = GridUtils.get_l_cells(start_grid, _last_drag_grid, _drag_corner_first_horizontal)
				ghost_preview.show_ghost(cells)
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

	# 滚轮上下滚均选中当前悬停建筑的类型（有意设计，非复制粘贴遗留）。
	# 设计意图：无论上滚还是下滚，都快速将物品栏切换到鼠标下方建筑对应的类型，
	# 降低操作门槛。未来如需方向性切换，可在此区分 WHEEL_UP/DOWN 语义。
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if building_manager.has_building(_last_hovered_grid):
			var type_id: String = building_manager.get_building_type(_last_hovered_grid)
			if inventory_bar and type_id != "default":
				inventory_bar.select_by_type_id(type_id)
			viewport.set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
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
				ghost_preview.show_ghost([grid_pos])
				_update_collector_ghost_range()
		InputStateMachine.State.DRAGGING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if grid_pos != start_grid:
				_last_drag_grid = grid_pos
				var cells: Array[Vector2i] = GridUtils.get_l_cells(start_grid, grid_pos, _drag_corner_first_horizontal)
				ghost_preview.show_ghost(cells)
			_update_collector_ghost_range()
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


func _update_collector_ghost_range() -> void:
	if not ghost_preview:
		return
	var is_collector_mode: bool = _is_building_placement_mode() and inventory_bar and \
		BuildingTypeManager.is_collector(inventory_bar.get_current_building_type())
	if is_collector_mode:
		ghost_preview.show_collector_ghost_range()
	else:
		ghost_preview.hide_collector_ghost_range()


## 打开源头类型选择面板
func _open_source_type_panel(source_node: SourceNode) -> void:
	if is_instance_valid(_current_type_panel):
		_current_type_panel.queue_free()
		_current_type_panel = null

	var panel: Control = ELEMENT_TYPE_PANEL_SCENE.instantiate()
	panel.target = source_node
	panel.mode = ElementTypePanel.Mode.SOURCE
	if _ui_overlay == null:
		panel.queue_free()
		return
	_ui_overlay.add_child(panel)
	_current_type_panel = panel


## 打开收集器筛选类型选择面板
func _open_collector_type_panel(collector: CollectorNode) -> void:
	if is_instance_valid(_current_type_panel):
		_current_type_panel.queue_free()
		_current_type_panel = null

	var panel: Control = ELEMENT_TYPE_PANEL_SCENE.instantiate()
	panel.target = collector
	panel.mode = ElementTypePanel.Mode.COLLECTOR
	if _ui_overlay == null:
		panel.queue_free()
		return
	_ui_overlay.add_child(panel)
	_current_type_panel = panel

func _handle_building_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.is_action("place_building") and event.pressed:
		if building_manager.has_building(grid_pos):
			# 放置模式下点击已有源头/收集器同样弹出类型选择面板（与选择模式行为一致）
			var node := building_manager.get_building_node(grid_pos)
			if node is SourceNode:
				_open_source_type_panel(node as SourceNode)
				viewport.set_input_as_handled()
				return
			if node is CollectorNode:
				_open_collector_type_panel(node as CollectorNode)
				viewport.set_input_as_handled()
				return
		var building_type: String = inventory_bar.get_current_building_type() if inventory_bar else "default"
		if not ProgressSystem.is_building_unlocked(building_type):
			return
		_state_machine.transition_to(InputStateMachine.State.DRAGGING, {
			"start_grid": grid_pos,
			"building_manager": building_manager,
			"building_type": building_type,
		})
		viewport.set_input_as_handled()
		return

	if event.is_action("place_building") and not event.pressed and _state_machine.current_state == InputStateMachine.State.DRAGGING:
		var ctx: Dictionary = _state_machine.context
		var start_grid: Vector2i = ctx.get("start_grid", Vector2i.ZERO)
		var building_type: String = ctx.get("building_type", "default")
		var cells: Array[Vector2i] = GridUtils.get_l_cells(start_grid, grid_pos, _drag_corner_first_horizontal)
		var placed: Dictionary = {}
		for cell: Vector2i in cells:
			if building_manager.place_building(cell, building_type):
				placed[cell] = {"type": building_type}
		if not placed.is_empty():
			var cmd: UndoCommand = UndoCommand.new()
			cmd.type = UndoCommand.Type.PLACE
			cmd.buildings = placed
			SelectionManager.push_undo_command(cmd)
			# 源头放置后弹出类型选择面板（最后放置的源头）
			if BuildingTypeManager.is_source(building_type):
				var last_source: SourceNode = null
				for cell: Vector2i in placed.keys():
					var placed_node := building_manager.get_building_node(cell)
					if placed_node is SourceNode:
						last_source = placed_node
				if last_source:
					_open_source_type_panel(last_source)
			# 收集器放置后弹出筛选面板（最后放置的收集器，与源头行为一致）
			elif BuildingTypeManager.is_collector(building_type):
				var last_collector: CollectorNode = null
				for cell: Vector2i in placed.keys():
					var placed_node := building_manager.get_building_node(cell)
					if placed_node is CollectorNode:
						last_collector = placed_node
				if last_collector:
					_open_collector_type_panel(last_collector)
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
				var entry: Dictionary = {"type": building_manager.get_building_type(cell)}
				var bdata := building_manager.get_building_data(cell)
				if bdata != null:
					# 先同步节点状态到 data，避免读到 stale 数据
					# （set_element_type/set_filter 只更新节点，不触发同步）
					var node := building_manager.get_building_node(cell)
					if node != null:
						BuildingDataSyncService.sync_from_node(bdata, node)
					# 源头：保存 element_type_id 用于撤销时恢复
					if BuildingTypeManager.is_source(bdata.building_type):
						if not bdata.element_type_id.is_empty():
							entry["element_type_id"] = bdata.element_type_id
					# 收集器：保存 collector_filter 用于撤销时恢复
					elif BuildingTypeManager.is_collector(bdata.building_type):
						entry["collector_filter"] = bdata.collector_filter
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
			# 点击源头/收集器弹出对应类型选择面板
			if node is SourceNode:
				_open_source_type_panel(node)
				viewport.set_input_as_handled()
				return
			if node is CollectorNode:
				_open_collector_type_panel(node)
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
