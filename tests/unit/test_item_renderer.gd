extends GutTest

## ItemRenderer 机器进出动画单测：直接构造事件数组调用 _on_sim_tick，
## 不依赖真实 tick/计时器，验证视觉键/插值状态设置正确（纯渲染逻辑）。

var _renderer: ItemRenderer = null
var _grid: ItemGrid = null

func before_each() -> void:
	_renderer = ItemRenderer.new()
	add_child_autoqfree(_renderer)
	_grid = ItemGrid.new()
	_renderer.setup(_grid)
	# 渲染器会连 EventBus.sim_tick_completed；测试直接用内部 _on_sim_tick 喂事件

func _cell_center(c: Vector2i) -> Vector2:
	return GridCoordinate.grid_to_world(c)

## 机器产出 spawn：物品从机器格中心滑到落点（起点=producer 格中心）
func test_spawn_with_producer_starts_from_machine_center() -> void:
	var events: Array[Dictionary] = [{
		"kind": "spawn",
		"at": Vector2i(2, 0),
		"item": Item.num(1),
		"producer": Vector2i(1, 0),   # 应用器在 (1,0) 向东输出 → (2,0)
	}]
	_renderer._on_sim_tick(events)
	var v: ItemRenderer.Visual = _renderer._visuals.get(Vector2i(2, 0)) as ItemRenderer.Visual
	assert_not_null(v, "spawn 后目标格应有视觉")
	if v == null:
		return
	assert_true(v.moving, "机器产出应启动滑入动画")
	assert_eq(v.from, _cell_center(Vector2i(1, 0)), "起点应为机器格中心")
	assert_eq(v.to, _cell_center(Vector2i(2, 0)), "终点应为落点格中心")
	assert_eq(v.node.position, _cell_center(Vector2i(1, 0)), "当前应定位在起点")

## 机器消费 despawn：视觉滑入机器格后进入 dying（字典移除但仍动画）
func test_despawn_with_consumer_slides_to_machine() -> void:
	# 先在 (2,0) 放一个视觉（模拟带格上有物品）
	_renderer._ensure_visual(Vector2i(2, 0), Item.num(5), _cell_center(Vector2i(2, 0)))
	var events: Array[Dictionary] = [{
		"kind": "despawn",
		"at": Vector2i(2, 0),
		"item": Item.num(5),
		"consumer": Vector2i(3, 0),   # 应用器在 (3,0)，输入口吃进
	}]
	_renderer._on_sim_tick(events)
	assert_false(_renderer._visuals.has(Vector2i(2, 0)), "消费后字典中应移除")
	assert_eq(_renderer._dying.size(), 1, "应有一个退场视觉在滑向机器")
	if _renderer._dying.size() == 1:
		var dv: ItemRenderer.Visual = _renderer._dying[0]
		assert_eq(dv.to, _cell_center(Vector2i(3, 0)), "退场终点应为消费机器格中心")
		assert_true(dv.moving, "退场视觉应处于动画中")

## 无 producer 的 spawn：保持原位出现（不启动动画，兼容旧行为）
func test_spawn_without_producer_stays_in_place() -> void:
	var events: Array[Dictionary] = [{
		"kind": "spawn",
		"at": Vector2i(2, 0),
		"item": Item.num(1),
	}]
	_renderer._on_sim_tick(events)
	var v: ItemRenderer.Visual = _renderer._visuals.get(Vector2i(2, 0)) as ItemRenderer.Visual
	assert_not_null(v, "spawn 后应有视觉")
	if v != null:
		assert_false(v.moving, "无 producer 的 spawn 不应启动动画")

## 同 tick 衔接 move：spawn(producer) 后紧接着被带子推进 → 起点保持机器口，终点延伸
func test_same_tick_move_keeps_machine_start() -> void:
	var events: Array[Dictionary] = [
		{"kind": "spawn", "at": Vector2i(2, 0), "item": Item.num(1), "producer": Vector2i(1, 0)},
		{"kind": "move", "from": Vector2i(2, 0), "to": Vector2i(3, 0), "item": Item.num(1)},
	]
	_renderer._on_sim_tick(events)
	var v: ItemRenderer.Visual = _renderer._visuals.get(Vector2i(3, 0)) as ItemRenderer.Visual
	assert_not_null(v, "move 后视觉应在目标格")
	if v == null:
		return
	assert_true(v.moving, "衔接推进应保持动画")
	assert_eq(v.from, _cell_center(Vector2i(1, 0)), "起点应保持机器口（不断点）")
	assert_eq(v.to, _cell_center(Vector2i(3, 0)), "终点应延伸到最后落点")
	assert_false(_renderer._visuals.has(Vector2i(2, 0)), "旧格视觉应移除")

## 跨 tick 的旧动画不误延伸：新 tick move 应重置起点（防止视觉从机器口跳变）
func test_cross_tick_move_resets_start() -> void:
	# 上一 tick 的 spawn producer 已在 (2,0) 建立动画且完成
	var spawn_events: Array[Dictionary] = [
		{"kind": "spawn", "at": Vector2i(2, 0), "item": Item.num(1), "producer": Vector2i(1, 0)},
	]
	_renderer._on_sim_tick(spawn_events)
	var v0: ItemRenderer.Visual = _renderer._visuals.get(Vector2i(2, 0)) as ItemRenderer.Visual
	v0.moving = false  # 模拟动画已结束（下一 tick 到来前）
	# 新 tick：带子把它推进
	var move_events: Array[Dictionary] = [
		{"kind": "move", "from": Vector2i(2, 0), "to": Vector2i(3, 0), "item": Item.num(1)},
	]
	_renderer._on_sim_tick(move_events)
	var v: ItemRenderer.Visual = _renderer._visuals.get(Vector2i(3, 0)) as ItemRenderer.Visual
	assert_not_null(v, "move 后视觉应在目标格")
	if v == null:
		return
	assert_eq(v.from, _cell_center(Vector2i(2, 0)), "跨 tick 推进应重置起点为源格")
	assert_eq(v.to, _cell_center(Vector2i(3, 0)), "终点应为目标格")

## despawn 动画结束后视觉被释放
func test_despawn_animation_completes_and_frees() -> void:
	_renderer._ensure_visual(Vector2i(2, 0), Item.num(5), _cell_center(Vector2i(2, 0)))
	var events: Array[Dictionary] = [{
		"kind": "despawn", "at": Vector2i(2, 0), "item": Item.num(5),
		"consumer": Vector2i(3, 0),
	}]
	_renderer._on_sim_tick(events)
	# 推进超过一个 tick 时长：动画完成，dying 清空
	_renderer._process(_renderer._tick_duration + 0.01)
	assert_eq(_renderer._dying.size(), 0, "动画结束后退场视觉应被释放")
	assert_false(_renderer._visuals.has(Vector2i(2, 0)), "原视觉键应保持移除")
