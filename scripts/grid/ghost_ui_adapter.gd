class_name GhostUIAdapter
extends RefCounted

var _ghost_preview: GhostPreviewManager
var _state_ui_map: Dictionary = {}

func _init(ghost_preview: GhostPreviewManager) -> void:
	_ghost_preview = ghost_preview
	_setup_state_ui_map()

func _setup_state_ui_map() -> void:
	_state_ui_map = {
		InputStateMachine.State.IDLE: _handle_idle_state,
		InputStateMachine.State.DRAGGING: _handle_dragging_state,
		InputStateMachine.State.REMOVING: _handle_removing_state,
		InputStateMachine.State.SELECTING: _handle_selecting_state,
		InputStateMachine.State.DESELECTING: _handle_deselecting_state,
		InputStateMachine.State.PASTE_DRAGGING: _handle_paste_dragging_state,
	}

func update_ui_for_state(state: InputStateMachine.State, context: Dictionary) -> void:
	var handler: Callable = _state_ui_map.get(state)
	if handler.is_valid():
		handler.call(context)

func _handle_idle_state(_context: Dictionary) -> void:
	_ghost_preview.hide_ghost()
	_ghost_preview.hide_remove_ghost()
	_ghost_preview.hide_select_ghost()
	_ghost_preview.hide_deselect_ghost()
	_ghost_preview.clear_paste_preview()
	_ghost_preview.hide_emitter_ghost_direction()
	_ghost_preview.hide_collector_ghost_range()

func _handle_dragging_state(context: Dictionary) -> void:
	var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
	_ghost_preview.show_ghost([start_grid])

func _handle_removing_state(context: Dictionary) -> void:
	var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
	_ghost_preview.show_remove_ghost([start_grid])

func _handle_selecting_state(context: Dictionary) -> void:
	var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
	_ghost_preview.show_select_ghost([start_grid])

func _handle_deselecting_state(context: Dictionary) -> void:
	var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
	_ghost_preview.show_deselect_ghost([start_grid])

func _handle_paste_dragging_state(context: Dictionary) -> void:
	var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
	var clipboard: Dictionary = context.get("clipboard", {})
	if not clipboard.is_empty():
		_ghost_preview.set_paste_preview_line([start_grid], clipboard)
