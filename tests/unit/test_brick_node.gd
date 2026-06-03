extends GutTest

func test_brick_node_get_building_name() -> void:
	load("res://scripts/building/brick_node.gd")
	var brick: BrickNode = autoqfree(load("res://scripts/building/brick_node.gd").new())
	add_child_autoqfree(brick)
	assert_eq(brick.get_building_name(), "砖块", "get_building_name 应返回'砖块'")

func test_brick_node_get_tooltip_summary() -> void:
	load("res://scripts/building/brick_node.gd")
	var brick: BrickNode = autoqfree(load("res://scripts/building/brick_node.gd").new())
	add_child_autoqfree(brick)
	assert_eq(brick.get_tooltip_summary(), {}, "get_tooltip_summary 应返回空字典")

func test_brick_node_has_static_body() -> void:
	load("res://scripts/building/brick_node.gd")
	var brick: BrickNode = autoqfree(load("res://scripts/building/brick_node.gd").new())
	add_child_autoqfree(brick)
	var body: StaticBody2D = brick.find_child("StaticBody2D", true, false)
	assert_not_null(body, "_ready 后应创建 StaticBody2D 子节点")

func test_brick_node_has_collision_shape() -> void:
	load("res://scripts/building/brick_node.gd")
	var brick: BrickNode = autoqfree(load("res://scripts/building/brick_node.gd").new())
	add_child_autoqfree(brick)
	var body: StaticBody2D = brick.find_child("StaticBody2D", true, false)
	if body:
		var shape: CollisionShape2D = body.find_child("CollisionShape2D", true, false)
		assert_not_null(shape, "StaticBody2D 下应有 CollisionShape2D")
