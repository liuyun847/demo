extends GutTest

var _pool: Node = null

func before_each() -> void:
	_pool = autoqfree(Node.new())
	_pool.set_script(load("res://scripts/autoload/essence_pool.gd"))
	_pool.set_value(0.0)
	add_child_autoqfree(_pool)

func test_essence_starts_at_zero() -> void:
	assert_eq(_pool.essence, 0.0, "初始源质应为 0")

func test_add_value() -> void:
	_pool.add(10.0)
	assert_eq(_pool.essence, 10.0, "add 后值应正确")

func test_subtract_value() -> void:
	_pool.add(10.0)
	_pool.subtract(3.0)
	assert_eq(_pool.essence, 7.0, "subtract 后值应正确")

func test_subtract_more_than_available() -> void:
	_pool.add(5.0)
	var actual: float = _pool.subtract(10.0)
	assert_eq(actual, 5.0, "不足时返回实际值")
	assert_eq(_pool.essence, 0.0, "不足时应归零")

func test_has_value() -> void:
	_pool.add(10.0)
	assert_true(_pool.has(5.0), "有足够源质")
	assert_false(_pool.has(15.0), "源质不足")

func test_set_value() -> void:
	_pool.set_value(50.0)
	assert_eq(_pool.essence, 50.0, "set_value 后值应正确")
