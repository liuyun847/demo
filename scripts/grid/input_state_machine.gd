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
var _ui_adapter: GhostUIAdapter = null

const _VALID_TRANSITIONS: Dictionary = {
	State.IDLE: [State.DRAGGING, State.REMOVING, State.SELECTING, State.DESELECTING, State.PASTE_DRAGGING],
	State.DRAGGING: [State.IDLE],
	State.REMOVING: [State.IDLE],
	State.SELECTING: [State.IDLE],
	State.DESELECTING: [State.IDLE],
	State.PASTE_DRAGGING: [State.IDLE],
}

func set_ui_adapter(adapter: GhostUIAdapter) -> void:
	_ui_adapter = adapter

func transition_to(new_state: State, new_context: Dictionary = {}) -> void:
	if not _is_transition_valid(current_state, new_state):
		push_warning("InputStateMachine: 非法状态转换 %s -> %s" % [State.keys()[current_state], State.keys()[new_state]])
		return
	_exit_state(current_state)
	current_state = new_state
	context = new_context
	_enter_state(current_state)

func _is_transition_valid(from_state: State, to_state: State) -> bool:
	if not _VALID_TRANSITIONS.has(from_state):
		return false
	var allowed: Array = _VALID_TRANSITIONS[from_state]
	return to_state in allowed

func reset() -> void:
	# 已在 IDLE 时不再触发转换，避免噪音 warning
	if current_state != State.IDLE:
		transition_to(State.IDLE)

func _exit_state(_state: State) -> void:
	# 退出任何状态时都切换到 IDLE 的 UI 状态（隐藏所有预览层），
	# 因为当前转换表只有 非IDLE→IDLE 和 IDLE→非IDLE 两种转换。
	# IDLE 处理器会清理所有幽灵预览，确保不残留。
	if _ui_adapter:
		_ui_adapter.update_ui_for_state(State.IDLE, context)

func _enter_state(state: State) -> void:
	if _ui_adapter:
		_ui_adapter.update_ui_for_state(state, context)
