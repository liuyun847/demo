extends GutTest

var _pool: Node = null

func before_each() -> void:
	_pool = autoqfree(Node.new())
	_pool.set_script(load("res://scripts/autoload/essence_pool.gd"))
	_pool.set_value(0.0)
	add_child_autoqfree(_pool)

func test_initial_essence_is_zero() -> void:
	assert_eq(_pool.essence, 0.0, "初始源质应为 0")

func test_add_increases_essence() -> void:
	_pool.add(10.0)
	assert_eq(_pool.essence, 10.0, "add(10) 后 essence 应为 10")

func test_add_zero_does_nothing() -> void:
	_pool.add(0.0)
	assert_eq(_pool.essence, 0.0, "add(0) 不应改变 essence")

func test_add_negative_does_nothing() -> void:
	_pool.add(-5.0)
	assert_eq(_pool.essence, 0.0, "add(-5) 不应改变 essence")

func test_subtract_reduces_essence() -> void:
	_pool.add(10.0)
	var actual: float = _pool.subtract(5.0)
	assert_eq(actual, 5.0, "subtract(5) 应返回 5")
	assert_eq(_pool.essence, 5.0, "subtract(5) 后 essence 应为 5")

func test_subtract_more_than_available() -> void:
	_pool.add(3.0)
	var actual: float = _pool.subtract(5.0)
	assert_eq(actual, 3.0, "不足时应返回实际值 3")
	assert_eq(_pool.essence, 0.0, "不足时应使 essence 归零")

func test_subtract_zero_or_negative() -> void:
	_pool.add(10.0)
	var actual_zero: float = _pool.subtract(0.0)
	assert_eq(actual_zero, 0.0, "subtract(0) 应返回 0")
	var actual_neg: float = _pool.subtract(-5.0)
	assert_eq(actual_neg, 0.0, "subtract(-5) 应返回 0")

func test_has_returns_correctly() -> void:
	_pool.add(10.0)
	assert_true(_pool.has(5.0), "essence=10, has(5) 应为 true")
	assert_true(_pool.has(10.0), "essence=10, has(10) 应为 true")
	assert_false(_pool.has(15.0), "essence=10, has(15) 应为 false")

func test_set_value() -> void:
	_pool.set_value(100.0)
	assert_eq(_pool.essence, 100.0, "set_value(100) 后 essence 应为 100")

func test_set_value_negative_clamps() -> void:
	_pool.set_value(-50.0)
	assert_eq(_pool.essence, 0.0, "set_value(-50) 后 essence 应为 0")

func test_add_multiple_times() -> void:
	_pool.add(5.0)
	_pool.add(3.0)
	_pool.add(2.0)
	assert_eq(_pool.essence, 10.0, "多次 add 总和应为 10")

func test_essence_changed_signal_on_add() -> void:
	var signal_values: Array[float] = []
	_pool.essence_changed.connect(_on_essence_changed.bind(signal_values))
	_pool.add(5.0)
	assert_eq(signal_values.size(), 1, "add 应发射信号")
	assert_eq(signal_values[0], 5.0, "信号值应为 5")

func test_essence_changed_signal_on_subtract() -> void:
	_pool.add(10.0)
	var signal_values: Array[float] = []
	_pool.essence_changed.connect(_on_essence_changed.bind(signal_values))
	_pool.subtract(4.0)
	assert_eq(signal_values.size(), 1, "subtract 应发射信号")
	assert_eq(signal_values[0], 6.0, "信号值应为 6")

func _on_essence_changed(new_value: float, values: Array[float]) -> void:
	values.append(new_value)
