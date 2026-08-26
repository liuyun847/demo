class_name ItemFlowCoordinator
extends Node

## 物品流协调器：ItemSimulator 的节点包装。
## 分帧模拟（与旧 ReactionCoordinator 同一模式）：0.1s Timer 仅置 _tick_pending 标记，
## 由 _process 每帧推进一个 tick 阶段（MACHINE → MOVE），把单帧峰值分摊到多帧；
## 低帧率下 tick 合并不堆积。_on_tick() 保留为同步完整 tick 供测试直调。
## 暂停即刻冻结：丢弃剩余阶段。物品不落盘：清除时由 BuildingManager 调用 clear_all()。
## tick 事件统一经 EventBus.sim_tick_completed 发射（渲染层监听）。

enum TickPhase {
	MACHINE,  ## 机器触发（输入/输出/计算）
	MOVE,     ## 传送带推进
	DONE,     ## 哨兵：>= DONE 表示本 tick 完成
}

var grid: ItemGrid = null

var _building_manager: BuildingManager = null
var _timer: Timer = null
var _paused: bool = false
var _tick_pending: bool = false
var _current_phase: int = -1
var _pending_events: Array[Dictionary] = []
var _machine_cells: Dictionary[Vector2i, bool] = {}

func init(building_manager: BuildingManager) -> void:
	_building_manager = building_manager

func _ready() -> void:
	EventBus.pause_state_changed.connect(_on_pause_state_changed)
	_timer = Timer.new()
	_timer.wait_time = GameConfig.SIMULATION_TICK_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	grid = ItemGrid.new()

func _exit_tree() -> void:
	if EventBus.pause_state_changed.is_connected(_on_pause_state_changed):
		EventBus.pause_state_changed.disconnect(_on_pause_state_changed)

func _on_timer_timeout() -> void:
	_tick_pending = true

## 每帧推进一个 tick 阶段（分帧模拟）
func _process(_delta: float) -> void:
	if _tick_pending and _current_phase < 0:
		_tick_pending = false
		if _building_manager == null or _paused:
			return
		_current_phase = TickPhase.MACHINE
	if _current_phase < 0:
		return
	if _paused:
		# 暂停立即冻结：丢弃剩余阶段，但先补发已产生的事件保持渲染一致
		_flush_pending_events()
		_current_phase = -1
		return
	_run_phase(_current_phase)
	_current_phase += 1
	if _current_phase >= TickPhase.DONE:
		_current_phase = -1

## 同步完整 tick（测试直接调用；语义与分帧路径一致，仅不跨帧）
func _on_tick() -> void:
	if _building_manager == null or _paused:
		return
	var events: Array[Dictionary] = []
	var machine_cells: Dictionary[Vector2i, bool] = ItemSimulator.machine_phase(_building_manager.buildings, grid, events)
	ItemSimulator.move_phase(_building_manager.buildings, machine_cells, grid, events)
	EventBus.sim_tick_completed.emit(events)

func _run_phase(phase: int) -> void:
	match phase:
		TickPhase.MACHINE:
			if _building_manager == null:
				_current_phase = TickPhase.DONE
				return
			_machine_cells = ItemSimulator.machine_phase(_building_manager.buildings, grid, _pending_events)
		TickPhase.MOVE:
			if _building_manager == null:
				_current_phase = TickPhase.DONE
				return
			ItemSimulator.move_phase(_building_manager.buildings, _machine_cells, grid, _pending_events)
			_flush_pending_events()

func _flush_pending_events() -> void:
	if _pending_events.is_empty():
		return
	var events := _pending_events
	_pending_events = []
	EventBus.sim_tick_completed.emit(events)

func _on_pause_state_changed(paused: bool) -> void:
	_paused = paused

## 清空物品（示例：清除建筑/载入新存档时）
func clear_all() -> void:
	if grid != null:
		grid.clear_all()
		_pending_events.clear()