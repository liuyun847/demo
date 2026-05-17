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

func _exit_state(state: State) -> void:
	match state:
		State.DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			if bm:
				bm.hide_ghost()
		State.REMOVING:
			var bm := context.get("building_manager") as BuildingManager
			if bm:
				bm.hide_remove_ghost()
		State.SELECTING:
			var bm := context.get("building_manager") as BuildingManager
			if bm:
				bm.hide_select_ghost()
		State.DESELECTING:
			var bm := context.get("building_manager") as BuildingManager
			if bm:
				bm.hide_deselect_ghost()
		State.PASTE_DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			if bm:
				bm.clear_paste_preview()

func _enter_state(state: State) -> void:
	match state:
		State.DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			if bm:
				bm.show_ghost([start_grid])
		State.REMOVING:
			var bm := context.get("building_manager") as BuildingManager
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			if bm:
				bm.show_remove_ghost([start_grid])
		State.SELECTING:
			var bm := context.get("building_manager") as BuildingManager
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			if bm:
				bm.show_select_ghost([start_grid])
		State.DESELECTING:
			var bm := context.get("building_manager") as BuildingManager
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			if bm:
				bm.show_deselect_ghost([start_grid])
		State.PASTE_DRAGGING:
			var bm := context.get("building_manager") as BuildingManager
			var start_grid: Vector2i = context.get("start_grid", Vector2i.ZERO)
			var clipboard: Dictionary = context.get("clipboard", {})
			if bm and not clipboard.is_empty():
				bm.set_paste_preview_line([start_grid], clipboard)
