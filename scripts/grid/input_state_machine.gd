class_name InputStateMachine
extends RefCounted

enum State {
	IDLE,
	DRAGGING,
	REMOVING,
	SELECTING,
	DESELECTING,
	PASTE_DRAGGING,
}

var current_state: State = State.IDLE
var context: Dictionary = {}

func transition_to(new_state: State, new_context: Dictionary = {}) -> void:
	_exit_state(current_state)
	current_state = new_state
	context = new_context
	_enter_state(current_state)

func reset() -> void:
	transition_to(State.IDLE)

func _get_ghost_preview(bm: BuildingManager) -> Node:
	if bm == null:
		return null
	return bm.get_node_or_null("GhostPreviewManager")


func _exit_state(state: State) -> void:
	match state:
		State.DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			if gp:
				gp.hide_ghost()
		State.REMOVING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			if gp:
				gp.hide_remove_ghost()
		State.SELECTING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			if gp:
				gp.hide_select_ghost()
		State.DESELECTING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			if gp:
				gp.hide_deselect_ghost()
		State.PASTE_DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			if gp:
				gp.clear_paste_preview()

func _enter_state(state: State) -> void:
	match state:
		State.DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			var cells: Array[Vector2i] = [start_grid]
			if gp:
				gp.show_ghost(cells)
		State.REMOVING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			var cells: Array[Vector2i] = [start_grid]
			if gp:
				gp.show_remove_ghost(cells)
		State.SELECTING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			var cells: Array[Vector2i] = [start_grid]
			if gp:
				gp.show_select_ghost(cells)
		State.DESELECTING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			var cells: Array[Vector2i] = [start_grid]
			if gp:
				gp.show_deselect_ghost(cells)
		State.PASTE_DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			var gp: Node = _get_ghost_preview(bm)
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			var cells: Array[Vector2i] = [start_grid]
			var clipboard: Dictionary = context.get("clipboard", {})
			if gp and not clipboard.is_empty():
				gp.set_paste_preview_line(cells, clipboard)
