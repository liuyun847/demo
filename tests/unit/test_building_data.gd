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

func test_is_emitter_water() -> void:
	assert_true(BuildingData.is_emitter(GameConfig.emitter_water_type_id), "水喷口是 emitter")

func test_is_emitter_fire() -> void:
	assert_true(BuildingData.is_emitter(GameConfig.emitter_fire_type_id), "火喷口是 emitter")

func test_is_emitter_earth() -> void:
	assert_true(BuildingData.is_emitter(GameConfig.emitter_earth_type_id), "土喷口是 emitter")

func test_is_emitter_non_emitter() -> void:
	assert_false(BuildingData.is_emitter(GameConfig.pipe_type_id), "管道不是 emitter")
	assert_false(BuildingData.is_emitter(GameConfig.brick_type_id), "砖块不是 emitter")
	assert_false(BuildingData.is_emitter("default"), "默认类型不是 emitter")

func test_is_collector() -> void:
	assert_true(BuildingData.is_collector(GameConfig.collector_type_id), "收集器是 collector")

func test_is_collector_non_collector() -> void:
	assert_false(BuildingData.is_collector(GameConfig.pipe_type_id), "管道不是 collector")
	assert_false(BuildingData.is_collector("default"), "默认类型不是 collector")

func test_is_emitter_node() -> void:
	load("res://scripts/building/emitter_node.gd")
	var emitter: EmitterNode = autoqfree(load("res://scripts/building/emitter_node.gd").new())
	assert_true(BuildingData.is_emitter_node(emitter), "EmitterNode 应返回 true")
	assert_false(BuildingData.is_emitter_node(Node2D.new()), "Node2D 应返回 false")

func test_is_collector_node() -> void:
	load("res://scripts/building/collector_node.gd")
	var collector: CollectorNode = autoqfree(load("res://scripts/building/collector_node.gd").new())
	assert_true(BuildingData.is_collector_node(collector), "CollectorNode 应返回 true")
	assert_false(BuildingData.is_collector_node(Node2D.new()), "Node2D 应返回 false")
