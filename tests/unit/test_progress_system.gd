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
	assert_true(MachineSpec.T_BELT in unlocked, "初始应解锁传送带")
	assert_true(_progress.is_building_unlocked(MachineSpec.T_BELT), "传送带应已解锁")

func test_is_building_unlocked_returns_false_for_unknown() -> void:
	assert_false(_progress.is_building_unlocked("type_99"), "不存在的建筑类型应为未解锁")

func test_buildings_remain_unlocked_after_higher_threshold() -> void:
	EssencePool.set_value(0.0)
	EssencePool.add(100.0)
	# ProgressSystem 通过 essence_changed 信号触发，_on_essence_changed 已经执行
	assert_true(_progress.is_building_unlocked(MachineSpec.T_BELT), "精华=100 时传送带应保持解锁")

func test_gradual_unlocking() -> void:
	EssencePool.set_value(0.0)
	var initial_unlocked: Array = _progress.get_unlocked_building_types()
	assert_eq(initial_unlocked.size(), 6, "纯搭建阶段应解锁全部 6 种建筑")

func test_get_unlocked_building_types_no_duplicates() -> void:
	var unlocked: Array = _progress.get_unlocked_building_types()
	var seen: Dictionary = {}
	for btype: String in unlocked:
		assert_false(seen.has(btype), "解锁列表中不应有重复: " + btype)
		seen[btype] = true

## 测试: essence_threshold_reached 信号发射的 unlocks 字典应为深拷贝
## 接收方修改字典不应影响 ProgressSystem 内部 _thresholds 数据
func test_essence_threshold_reached_emits_deep_copy() -> void:
	# 用 lambda 捕获信号参数（_ready 已解锁过阈值 0，先重置已解锁集合重新触发）
	var captured := [false, 0.0, {}]
	var cb := func(t: float, u: Dictionary) -> void:
		captured[0] = true
		captured[1] = t
		captured[2] = u
	EventBus.essence_threshold_reached.connect(cb)
	# _ready 已解锁过阈值 0；Object.set 对类型化字典静默失败，直接用 clear() 重置
	_progress._unlocked_thresholds.clear()
	_progress._on_essence_changed(0.0)
	EventBus.essence_threshold_reached.disconnect(cb)

	assert_true(captured[0], "应发射 essence_threshold_reached 信号")
	assert_eq(captured[1], 0.0, "纯搭建阶段应解锁阈值 0")
	var received: Dictionary = captured[2]
	# 修改接收到的字典，验证是否为深拷贝
	received["new_key"] = "new_value"
	var thresholds: Array = _progress.get("_thresholds")
	var entry: Dictionary = thresholds[0]
	var internal_unlocks: Dictionary = entry["unlocks"]
	assert_false(internal_unlocks.has("new_key"), "内部数据不应包含接收方添加的键")
	assert_true(internal_unlocks.has("buildings"), "内部数据应保留解锁建筑列表")
