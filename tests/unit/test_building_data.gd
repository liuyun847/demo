extends GutTest

func test_has_capacity_container() -> void:
	assert_true(BuildingData.has_capacity(GameConfig.container_type_id), "容器类型应有容量")

func test_has_capacity_non_container() -> void:
	assert_false(BuildingData.has_capacity(GameConfig.pipe_type_id), "管道类型不应有容量")
	assert_false(BuildingData.has_capacity("default"), "默认类型不应有容量")

func test_is_fluid_building_container() -> void:
	assert_true(BuildingData.is_fluid_building(GameConfig.container_type_id), "容器是流体建筑")

func test_is_fluid_building_pipe() -> void:
	assert_true(BuildingData.is_fluid_building(GameConfig.pipe_type_id), "管道是流体建筑")

func test_is_fluid_building_default() -> void:
	assert_false(BuildingData.is_fluid_building("default"), "默认类型不是流体建筑")

func test_is_fluid_building_brick() -> void:
	assert_false(BuildingData.is_fluid_building(GameConfig.brick_type_id), "砖块不是流体建筑")

func test_is_container_building_with_container() -> void:
	load("res://scripts/building/container_node.gd")
	var node: ContainerNode = autoqfree(load("res://scripts/building/container_node.gd").new())
	assert_true(BuildingData.is_container_building(node), "ContainerNode 应返回 true")

func test_is_container_building_with_pipe() -> void:
	load("res://scripts/building/pipe_node.gd")
	var node: PipeNode = autoqfree(load("res://scripts/building/pipe_node.gd").new())
	assert_false(BuildingData.is_container_building(node), "PipeNode 应返回 false")
