extends GutTest

# ===== ContainerNode 测试 =====

func test_container_node_defaults():
	var node = autoqfree(ContainerNode.new())
	assert_eq(node.capacity, 0, "默认 capacity 应为 0")
	assert_eq(node.max_capacity, 100, "默认 max_capacity 应为 100")

func test_container_node_get_fill_ratio_empty():
	var node = autoqfree(ContainerNode.new())
	assert_eq(node.get_fill_ratio(), 0.0, "空容器填充率应为 0.0")

func test_container_node_get_fill_ratio_full():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 100
	assert_eq(node.get_fill_ratio(), 1.0, "满容器填充率应为 1.0")

func test_container_node_get_fill_ratio_half():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 50
	assert_eq(node.get_fill_ratio(), 0.5, "50/100 填充率应为 0.5")

func test_container_node_get_pressure():
	var node = autoqfree(ContainerNode.new())
	assert_eq(node.get_pressure(), 0.0, "容器压力应恒为 0.0")

func test_container_node_add():
	var node = autoqfree(ContainerNode.new())
	var added = node.add(30)
	assert_eq(added, 30, "应返回实际添加量")
	assert_eq(node.capacity, 30, "capacity 应增加 30")

func test_container_node_add_overflow():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 80
	var added = node.add(50)
	assert_eq(added, 20, "超出 max_capacity 的部分应被截断")
	assert_eq(node.capacity, 100, "capacity 应被限制在 max_capacity")

func test_container_node_remove():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 80
	var removed = node.remove(30)
	assert_eq(removed, 30, "应返回实际移除量")
	assert_eq(node.capacity, 50, "capacity 应减少 30")

func test_container_node_remove_underflow():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 20
	var removed = node.remove(50)
	assert_eq(removed, 20, "移除量不应超过当前 capacity")
	assert_eq(node.capacity, 0, "capacity 不应低于 0")

func test_container_node_capacity_clamp():
	var node = autoqfree(ContainerNode.new())
	node.capacity = -10
	assert_eq(node.capacity, 0, "capacity 不应低于 0")

func test_container_node_building_name():
	var node = autoqfree(ContainerNode.new())
	assert_eq(node.get_building_name(), "容器", "建筑名称应为 容器")

func test_container_node_tooltip_summary():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 30
	var summary = node.get_tooltip_summary()
	assert_true(summary.has("容量"), "摘要应包含 容量")
	assert_eq(summary["容量"], "30 / 100")

func test_container_node_tooltip_details():
	var node = autoqfree(ContainerNode.new())
	node.capacity = 75
	var details = node.get_tooltip_details()
	assert_true(details.has("填充率"), "详情应包含 填充率")
	assert_true(details.has("压力"), "详情应包含 压力")

func test_container_node_set_max_capacity():
	var node = autoqfree(ContainerNode.new())
	node.max_capacity = 200
	assert_eq(node.max_capacity, 200, "max_capacity 应更新为 200")

func test_container_node_set_max_capacity_min():
	var node = autoqfree(ContainerNode.new())
	node.max_capacity = 0
	assert_eq(node.max_capacity, 1, "max_capacity 应至少为 1")

# ===== PipeNode 测试 =====

func test_pipe_node_defaults():
	var node = autoqfree(PipeNode.new())
	assert_eq(node.capacity, 0, "默认 capacity 应为 0")
	assert_eq(node.max_capacity, 5, "默认 max_capacity 应为 5")
	assert_eq(node.connection_mask, 0, "默认 connection_mask 应为 0")

func test_pipe_node_get_fill_ratio():
	var node = autoqfree(PipeNode.new())
	assert_eq(node.get_fill_ratio(), 0.0, "空管道填充率应为 0.0")
	node.capacity = 5
	assert_eq(node.get_fill_ratio(), 1.0, "满管道填充率应为 1.0")

func test_pipe_node_get_pressure():
	var node = autoqfree(PipeNode.new())
	assert_eq(node.get_pressure(), 0.0, "空管道压力应为 0.0")
	node.capacity = 3
	assert_eq(node.get_pressure(), 0.6, "3/5 管道压力应为 0.6")

func test_pipe_node_add():
	var node = autoqfree(PipeNode.new())
	var added = node.add(3)
	assert_eq(added, 3, "应返回实际添加量")
	assert_eq(node.capacity, 3)

func test_pipe_node_add_overflow():
	var node = autoqfree(PipeNode.new())
	node.capacity = 4
	var added = node.add(5)
	assert_eq(added, 1, "超出 max_capacity 应截断")
	assert_eq(node.capacity, 5)

func test_pipe_node_remove():
	var node = autoqfree(PipeNode.new())
	node.capacity = 4
	var removed = node.remove(2)
	assert_eq(removed, 2)
	assert_eq(node.capacity, 2)

func test_pipe_node_remove_underflow():
	var node = autoqfree(PipeNode.new())
	node.capacity = 2
	var removed = node.remove(5)
	assert_eq(removed, 2)
	assert_eq(node.capacity, 0)

func test_pipe_node_building_name():
	var node = autoqfree(PipeNode.new())
	assert_eq(node.get_building_name(), "管道", "建筑名称应为 管道")

func test_pipe_node_tooltip_summary():
	var node = autoqfree(PipeNode.new())
	node.capacity = 2
	var summary = node.get_tooltip_summary()
	assert_true(summary.has("容量"), "摘要应包含 容量")

func test_pipe_node_tooltip_details():
	var node = autoqfree(PipeNode.new())
	var details = node.get_tooltip_details()
	assert_true(details.has("连接方向"), "详情应包含 连接方向")
	assert_eq(details["连接方向"], "无", "无连接时应显示 无")

func test_pipe_node_max_capacity():
	var node = autoqfree(PipeNode.new())
	node.max_capacity = 10
	assert_eq(node.max_capacity, 10)
	node.max_capacity = 0
	assert_eq(node.max_capacity, 1, "最小应为 1")

# ===== WaterSourceNode 测试 =====

func test_water_source_node_defaults():
	var node = autoqfree(WaterSourceNode.new())
	assert_eq(node.output_per_tick, 30, "默认 output_per_tick 应为 30")
	assert_eq(node.remaining_output, 0, "默认 remaining_output 应为 0")

func test_water_source_node_get_pressure():
	var node = autoqfree(WaterSourceNode.new())
	assert_eq(node.get_pressure(), 1.0, "水源压力应恒为 1.0")

func test_water_source_node_building_name():
	var node = autoqfree(WaterSourceNode.new())
	assert_eq(node.get_building_name(), "水源", "建筑名称应为 水源")

func test_water_source_node_tooltip_summary():
	var node = autoqfree(WaterSourceNode.new())
	var summary = node.get_tooltip_summary()
	assert_true(summary.has("每 tick 产出"), "摘要应包含 每 tick 产出")
	assert_eq(summary["每 tick 产出"], "30")

func test_water_source_node_tooltip_details():
	var node = autoqfree(WaterSourceNode.new())
	var details = node.get_tooltip_details()
	assert_true(details.has("压力"), "详情应包含 压力")
	assert_true(details.has("剩余待输出"), "详情应包含 剩余待输出")
