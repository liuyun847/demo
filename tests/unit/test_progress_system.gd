extends GutTest

var _progress: Node = null
var _start_essence: float = 0.0

func before_all() -> void:
	_start_essence = EssencePool.essence

func before_each() -> void:
	_progress = autoqfree(Node.new())
	_progress.set_script(load("res://scripts/autoload/progress_system.gd"))
	add_child_autoqfree(_progress)
	EssencePool.set_value(_start_essence)

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
