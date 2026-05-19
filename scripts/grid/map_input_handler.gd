extends Node

@export var building_manager: BuildingManager = null
@export var inventory_bar: InventoryBar = null

@onready var ghost_preview: GhostPreviewManager = %BuildingManager/GhostPreviewManager

var _state_machine: InputStateMachine = InputStateMachine.new()

var _last_hovered_grid: Vector2i = Vector2i(-99999, -99999)
var _has_camera: bool = false
var _drag_corner_first_horizontal: bool = true
var _last_drag_grid: Vector2i = Vector2i.ZERO

func _ready() -> void:
	if not building_manager:
		building_manager = %BuildingManager as BuildingManager
	if not inventory_bar:
		inventory_bar = %InventoryBar as InventoryBar
	if not ghost_preview and building_manager:
		ghost_preview = building_manager.get_node_or_null("GhostPreviewManager") as GhostPreviewManager
	if inventory_bar:
		inventory_bar.slot_selected.connect(_on_slot_selected)
	EventBus.paste_mode_changed.connect(_on_paste_mode_changed)
	_has_camera = get_viewport().get_camera_2d() != null

func _on_slot_selected(index: int, _type_id: String) -> void:
	if index < 0:
		_cancel_all_dragging()

func _on_paste_mode_changed(_active: bool) -> void:
	_cancel_all_dragging()

func _cancel_all_dragging() -> void:
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
	if event.is_action_pressed("rotate_clipboard") and not event.is_echo():
		if _state_machine.current_state == InputStateMachine.State.DRAGGING:
			_drag_corner_first_horizontal = not _drag_corner_first_horizontal
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if start_grid != _last_drag_grid:
				var cells: Array[Vector2i] = GridUtils.get_l_cells(start_grid, _last_drag_grid, _drag_corner_first_horizontal)
				building_manager.show_ghost(cells)
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
		InputStateMachine.State.DRAGGING:
			var start_grid: Vector2i = _state_machine.context.get("start_grid", Vector2i.ZERO)
			if grid_pos != start_grid:
				_last_drag_grid = grid_pos
				var cells: Array[Vector2i] = GridUtils.get_l_cells(start_grid, grid_pos, _drag_corner_first_horizontal)
				ghost_preview.show_ghost(cells)
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

func _handle_building_mode(event: InputEventMouseButton, grid_pos: Vector2i, viewport: Viewport) -> void:
	if event.is_action("place_building") and event.pressed:
		var building_type: String = inventory_bar.get_current_building_type() if inventory_bar else "default"
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
				removed[cell] = {"type": building_manager.get_building_type(cell)}
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
