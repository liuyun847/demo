extends GutTest

func test_has_capacity_container() -> void:
	assert_true(BuildingData.has_capacity(GameConfig.container_type_id), "容器类型应有容量")

func test_has_capacity_non_container() -> void:
	assert_false(BuildingData.has_capacity(GameConfig.pipe_type_id), "管道类型不应有容量")
	assert_false(BuildingData.has_capacity("default"), "默认类型不应有容量")

func test_is_pipe_or_buffer_container() -> void:
	assert_true(BuildingData.is_pipe_or_buffer(GameConfig.container_type_id), "容器是管道或缓存节点")

func test_is_pipe_or_buffer_pipe() -> void:
	assert_true(BuildingData.is_pipe_or_buffer(GameConfig.pipe_type_id), "管道是管道或缓存节点")

func test_is_pipe_or_buffer_default() -> void:
	assert_false(BuildingData.is_pipe_or_buffer("default"), "默认类型不是管道或缓存节点")

func test_is_pipe_or_buffer_brick() -> void:
	assert_false(BuildingData.is_pipe_or_buffer(GameConfig.brick_type_id), "砖块不是管道或缓存节点")

func test_is_container_building_with_container() -> void:
	load("res://scripts/building/container_node.gd")
	var node: ContainerNode = autoqfree(load("res://scripts/building/container_node.gd").new())
	assert_true(BuildingData.is_container_building(node), "ContainerNode 应返回 true")

func test_is_container_building_with_pipe() -> void:
	load("res://scripts/building/pipe_node.gd")
	var node: PipeNode = autoqfree(load("res://scripts/building/pipe_node.gd").new())
	assert_false(BuildingData.is_container_building(node), "PipeNode 应返回 false")
