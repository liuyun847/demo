extends GutTest

var _fsm: InputStateMachine = null

func before_each() -> void:
	_fsm = InputStateMachine.new()

func after_each() -> void:
	_fsm = null

# ── 初始状态 ──

func test_initial_state_is_idle() -> void:
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "初始状态应为 IDLE")

func test_initial_context_is_empty() -> void:
	assert_true(_fsm.context.is_empty(), "初始 context 应为空")

# ── 合法转换：IDLE → 各状态 ──

func test_transition_idle_to_dragging() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING, {"start_grid": Vector2i(0, 0)})
	assert_eq(_fsm.current_state, InputStateMachine.State.DRAGGING, "IDLE → DRAGGING 应合法")

func test_transition_idle_to_removing() -> void:
	_fsm.transition_to(InputStateMachine.State.REMOVING)
	assert_eq(_fsm.current_state, InputStateMachine.State.REMOVING, "IDLE → REMOVING 应合法")

func test_transition_idle_to_selecting() -> void:
	_fsm.transition_to(InputStateMachine.State.SELECTING)
	assert_eq(_fsm.current_state, InputStateMachine.State.SELECTING, "IDLE → SELECTING 应合法")

func test_transition_idle_to_deselecting() -> void:
	_fsm.transition_to(InputStateMachine.State.DESELECTING)
	assert_eq(_fsm.current_state, InputStateMachine.State.DESELECTING, "IDLE → DESELECTING 应合法")

func test_transition_idle_to_paste_dragging() -> void:
	_fsm.transition_to(InputStateMachine.State.PASTE_DRAGGING)
	assert_eq(_fsm.current_state, InputStateMachine.State.PASTE_DRAGGING, "IDLE → PASTE_DRAGGING 应合法")

# ── 合法转换：各状态 → IDLE ──

func test_transition_dragging_to_idle() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "DRAGGING → IDLE 应合法")

func test_transition_removing_to_idle() -> void:
	_fsm.transition_to(InputStateMachine.State.REMOVING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "REMOVING → IDLE 应合法")

func test_transition_selecting_to_idle() -> void:
	_fsm.transition_to(InputStateMachine.State.SELECTING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "SELECTING → IDLE 应合法")

func test_transition_deselecting_to_idle() -> void:
	_fsm.transition_to(InputStateMachine.State.DESELECTING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "DESELECTING → IDLE 应合法")

func test_transition_paste_dragging_to_idle() -> void:
	_fsm.transition_to(InputStateMachine.State.PASTE_DRAGGING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "PASTE_DRAGGING → IDLE 应合法")

# ── 非法转换 ──

func test_illegal_transition_dragging_to_selecting() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING)
	_fsm.transition_to(InputStateMachine.State.SELECTING)
	assert_eq(_fsm.current_state, InputStateMachine.State.DRAGGING, "DRAGGING → SELECTING 非法，状态应保持不变")

func test_illegal_transition_removing_to_dragging() -> void:
	_fsm.transition_to(InputStateMachine.State.REMOVING)
	_fsm.transition_to(InputStateMachine.State.DRAGGING)
	assert_eq(_fsm.current_state, InputStateMachine.State.REMOVING, "REMOVING → DRAGGING 非法，状态应保持不变")

func test_illegal_transition_selecting_to_removing() -> void:
	_fsm.transition_to(InputStateMachine.State.SELECTING)
	_fsm.transition_to(InputStateMachine.State.REMOVING)
	assert_eq(_fsm.current_state, InputStateMachine.State.SELECTING, "SELECTING → REMOVING 非法，状态应保持不变")

func test_illegal_transition_deselecting_to_paste_dragging() -> void:
	_fsm.transition_to(InputStateMachine.State.DESELECTING)
	_fsm.transition_to(InputStateMachine.State.PASTE_DRAGGING)
	assert_eq(_fsm.current_state, InputStateMachine.State.DESELECTING, "DESELECTING → PASTE_DRAGGING 非法，状态应保持不变")

func test_illegal_transition_paste_dragging_to_selecting() -> void:
	_fsm.transition_to(InputStateMachine.State.PASTE_DRAGGING)
	_fsm.transition_to(InputStateMachine.State.SELECTING)
	assert_eq(_fsm.current_state, InputStateMachine.State.PASTE_DRAGGING, "PASTE_DRAGGING → SELECTING 非法，状态应保持不变")

# ── reset ──

func test_reset_from_dragging() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING, {"start_grid": Vector2i(1, 1)})
	_fsm.reset()
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "reset() 后应回到 IDLE")
	assert_true(_fsm.context.is_empty(), "reset() 后 context 应清空")

func test_reset_from_removing() -> void:
	_fsm.transition_to(InputStateMachine.State.REMOVING)
	_fsm.reset()
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "从 REMOVING reset() 后应回到 IDLE")

func test_reset_from_paste_dragging() -> void:
	_fsm.transition_to(InputStateMachine.State.PASTE_DRAGGING)
	_fsm.reset()
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "从 PASTE_DRAGGING reset() 后应回到 IDLE")

# ── context 传递 ──

func test_context_preserved_on_transition() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING, {"start_grid": Vector2i(5, -3), "building_type": "pipe"})
	assert_eq(_fsm.context.get("start_grid"), Vector2i(5, -3), "DRAGGING 的 context 应保留 start_grid")
	assert_eq(_fsm.context.get("building_type"), "pipe", "DRAGGING 的 context 应保留 building_type")

func test_context_replaced_on_new_transition() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING, {"start_grid": Vector2i(1, 1)})
	_fsm.transition_to(InputStateMachine.State.IDLE)
	_fsm.transition_to(InputStateMachine.State.REMOVING, {"start_grid": Vector2i(9, 9)})
	assert_eq(_fsm.context.get("start_grid"), Vector2i(9, 9), "新的合法转换应替换 context")

# ── 完整状态转换切换 ──

func test_full_cycle() -> void:
	_fsm.transition_to(InputStateMachine.State.DRAGGING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	_fsm.transition_to(InputStateMachine.State.REMOVING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	_fsm.transition_to(InputStateMachine.State.SELECTING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	_fsm.transition_to(InputStateMachine.State.DESELECTING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	_fsm.transition_to(InputStateMachine.State.PASTE_DRAGGING)
	_fsm.transition_to(InputStateMachine.State.IDLE)
	assert_eq(_fsm.current_state, InputStateMachine.State.IDLE, "完整状态切换周期后应回到 IDLE")