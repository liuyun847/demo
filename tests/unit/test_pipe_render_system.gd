extends GutTest

var _prs: Node = null

func before_each() -> void:
	load("res://scripts/building/pipe_render_system.gd")
	_prs = autoqfree(load("res://scripts/building/pipe_render_system.gd").new())
	add_child_autoqfree(_prs)

func _make_pipe(pos: Vector2, mask: int = 0) -> PipeNode:
	load("res://scripts/building/pipe_node.gd")
	var pipe: PipeNode = autoqfree(load("res://scripts/building/pipe_node.gd").new())
	add_child_autoqfree(pipe)
	pipe.position = pos
	pipe.connection_mask = mask
	return pipe

func test_register_pipe() -> void:
	var pipe := _make_pipe(Vector2(100, 100))
	_prs.register_pipe(pipe)
	assert_eq(_prs._pipe_positions.size(), 1, "注册后位置数组长度应为 1")
	assert_eq(_prs._pipe_masks.size(), 1, "注册后掩码数组长度应为 1")
	assert_eq(_prs._pipe_positions[0], Vector2(100, 100), "位置应正确")

func test_register_pipe_then_unregister() -> void:
	var pipe := _make_pipe(Vector2(50, 50))
	_prs.register_pipe(pipe)
	assert_eq(_prs._pipe_positions.size(), 1, "注册后应有 1 个管道")
	_prs.unregister_pipe(pipe)
	assert_eq(_prs._pipe_positions.size(), 0, "注销后应有 0 个管道")

func test_unregister_nonexistent() -> void:
	var pipe := _make_pipe(Vector2.ZERO)
	_prs.unregister_pipe(pipe)
	assert_true(true, "注销不存在管道不应崩溃")

func test_unregister_last_element() -> void:
	var pipe_a := _make_pipe(Vector2(10, 10))
	var pipe_b := _make_pipe(Vector2(20, 20))
	_prs.register_pipe(pipe_a)
	_prs.register_pipe(pipe_b)
	assert_eq(_prs._pipe_positions.size(), 2, "注册后应有 2 个管道")
	_prs.unregister_pipe(pipe_b)
	assert_eq(_prs._pipe_positions.size(), 1, "注销最后一个后应有 1 个管道")
	assert_eq(_prs._pipe_positions[0], Vector2(10, 10), "剩下的应是管道A")

func test_clear_all() -> void:
	var pipe := _make_pipe(Vector2(100, 100))
	_prs.register_pipe(pipe)
	_prs.clear_all()
	assert_true(_prs._pipe_positions.is_empty(), "clear_all 后位置数组应为空")
	assert_true(_prs._pipe_masks.is_empty(), "clear_all 后掩码数组应为空")
	assert_true(_prs._pipe_ids.is_empty(), "clear_all 后 ID 数组应为空")
	assert_true(_prs._pipe_index_map.is_empty(), "clear_all 后索引映射应为空")
