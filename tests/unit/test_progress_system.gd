extends GutTest

var _progress: Node = null
var _start_essence: float = 0.0

func before_all() -> void:
	_start_essence = EssencePool.essence

func before_each() -> void:
	# 先重置精华，确保 _ready() 中只解锁阈值 0，避免上一测试的精华值提前解锁后续阈值
	EssencePool.set_value(0.0)
	_progress = autoqfree(Node.new())
	_progress.set_script(load("res://scripts/autoload/progress_system.gd"))
	add_child_autoqfree(_progress)

func after_each() -> void:
	EssencePool.set_value(_start_essence)

func test_initial_buildings_unlocked_at_zero() -> void:
	var unlocked: Array = _progress.get_unlocked_building_types()
	assert_true(unlocked.size() > 0, "精华=0 时应有初始解锁建筑")
	assert_true("type_02" in unlocked, "初始应解锁 type_02")
	assert_true(_progress.is_building_unlocked("type_02"), "type_02 应已解锁")

func test_is_building_unlocked_returns_false_for_unknown() -> void:
	assert_false(_progress.is_building_unlocked("type_99"), "不存在的建筑类型应为未解锁")

func test_buildings_remain_unlocked_after_higher_threshold() -> void:
	EssencePool.set_value(0.0)
	EssencePool.add(100.0)
	# ProgressSystem 通过 essence_changed 信号触发，_on_essence_changed 已经执行
	assert_true(_progress.is_building_unlocked("type_02"), "精华=100 时 type_02 应保持解锁")

func test_gradual_unlocking() -> void:
	EssencePool.set_value(0.0)
	var initial_unlocked: Array = _progress.get_unlocked_building_types()
	assert_eq(initial_unlocked.size(), 4, "初始应解锁 4 种建筑")

func test_get_unlocked_building_types_no_duplicates() -> void:
	var unlocked: Array = _progress.get_unlocked_building_types()
	var seen: Dictionary = {}
	for btype: String in unlocked:
		assert_false(seen.has(btype), "解锁列表中不应有重复: " + btype)
		seen[btype] = true

## 测试11: essence_threshold_reached 信号发射的 unlocks 字典应为深拷贝
## 接收方修改字典不应影响 ProgressSystem 内部 _thresholds 数据
func test_essence_threshold_reached_emits_deep_copy() -> void:
	# 监听 EventBus 信号
	watch_signals(EventBus)
	# 直接调用本测试实例的 _on_essence_changed 触发 threshold=500 解锁
	# before_each 可能因 EssencePool 状态差异导致 100 未解锁，故先确保 100 已解锁
	_progress._on_essence_changed(100.0)
	_progress._on_essence_changed(500.0)

	# 应发射 essence_threshold_reached 信号
	assert_signal_emitted(EventBus, "essence_threshold_reached", "应发射 essence_threshold_reached 信号")
	# 获取最后一次发射的参数（应为 threshold=500 的解锁）
	var params: Array = get_signal_parameters(EventBus, "essence_threshold_reached", -1)
	if params == null or params.size() < 2:
		return
	# 验证最后一次发射对应 threshold=500
	assert_eq(float(params[0]), 500.0, "最后一次发射应为 threshold=500")
	var received: Dictionary = params[1]
	# 修改接收到的字典，验证是否为深拷贝
	received["description"] = "MODIFIED"
	received["new_key"] = "new_value"
	# 验证 ProgressSystem 内部数据未被影响（threshold=500 对应 _thresholds[2]）
	var thresholds: Array = _progress.get("_thresholds")
	var entry: Dictionary = thresholds[2]
	var internal_unlocks: Dictionary = entry["unlocks"]
	assert_eq(internal_unlocks["description"], "A 型建筑升级（多方向输出）", "内部数据不应被接收方修改")
	assert_false(internal_unlocks.has("new_key"), "内部数据不应包含接收方添加的键")
