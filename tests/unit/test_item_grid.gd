extends GutTest

var _grid: ItemGrid = null

func before_each() -> void:
	_grid = ItemGrid.new()

func after_each() -> void:
	_grid = null

func test_empty_grid() -> void:
	assert_true(_grid.is_empty())
	assert_false(_grid.has_item(Vector2i(0, 0)))
	assert_null(_grid.get_item(Vector2i(0, 0)))
	assert_eq(_grid.count_items(), 0)

func test_set_and_get() -> void:
	_grid.set_item(Vector2i(2, 3), Item.num(5))
	assert_true(_grid.has_item(Vector2i(2, 3)))
	assert_eq(_grid.get_item(Vector2i(2, 3)).value, 5)
	assert_eq(_grid.count_items(), 1)

func test_set_overwrites() -> void:
	_grid.set_item(Vector2i(0, 0), Item.num(1))
	_grid.set_item(Vector2i(0, 0), Item.num(2))
	assert_eq(_grid.get_item(Vector2i(0, 0)).value, 2, "重复设置应覆盖")
	assert_eq(_grid.count_items(), 1)

func test_take_item() -> void:
	_grid.set_item(Vector2i(0, 0), Item.num(1))
	var item := _grid.take_item(Vector2i(0, 0))
	assert_not_null(item)
	assert_eq(item.value, 1)
	assert_false(_grid.has_item(Vector2i(0, 0)))

func test_take_missing_returns_null() -> void:
	assert_null(_grid.take_item(Vector2i(9, 9)))

func test_remove_item() -> void:
	_grid.set_item(Vector2i(0, 0), Item.num(1))
	_grid.remove_item(Vector2i(0, 0))
	assert_false(_grid.has_item(Vector2i(0, 0)))

func test_clear_all() -> void:
	_grid.set_item(Vector2i(0, 0), Item.num(1))
	_grid.set_item(Vector2i(1, 0), Item.num(2))
	_grid.clear_all()
	assert_true(_grid.is_empty())

func test_occupied_cells() -> void:
	_grid.set_item(Vector2i(0, 0), Item.num(1))
	_grid.set_item(Vector2i(5, 5), Item.num(2))
	assert_eq(_grid.get_occupied_cells().size(), 2)