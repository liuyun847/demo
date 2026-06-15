extends GutTest

const _ContainerNode = preload("res://scripts/building/container_node.gd")
const _PipeNodeScript = preload("res://scripts/building/pipe_node.gd")
const _BuildingData = preload("res://scripts/resources/building_data.gd")
const _BM = preload("res://scripts/building/building_manager.gd")


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.container_type_id):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.container_type_id, {"has_capacity": true, "is_buffer": true}],
		[GameConfig.pipe_type_id,      {"is_pipe": true}],
		[GameConfig.emitter_type_id,   {"is_emitter": true}],
		[GameConfig.collector_type_id, {"is_collector": true}],
		[GameConfig.brick_type_id,     {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		types.append(td)
	BuildingTypeManager.register_all(types)


func _setup_bm() -> BuildingManager:
	var bm: BuildingManager = autoqfree(_BM.new() as BuildingManager)
	var pr: PipeRenderSystem = preload("res://scripts/building/pipe_render_system.gd").new()
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	return bm

func test_building_data_creation() -> void:
	var data: BuildingData = BuildingData.new()
	data.grid_position = Vector2i(3, 5)
	data.building_type = "type_01"
	data.capacity = 50
	data.max_capacity = 100

	assert_eq(data.grid_position, Vector2i(3, 5), "grid_position 应正确赋值")
	assert_eq(data.building_type, "type_01", "building_type 应正确赋值")
	assert_eq(data.capacity, 50, "capacity 应正确赋值")
	assert_eq(data.max_capacity, 100, "max_capacity 应正确赋值")

func test_building_data_defaults() -> void:
	var data: BuildingData = BuildingData.new()
	assert_eq(data.building_type, "default", "默认 building_type 应为 default")
	assert_eq(data.capacity, 0, "默认 capacity 应为 0")
	assert_eq(data.max_capacity, 100, "默认 max_capacity 应为 100")

func test_has_capacity_for_container() -> void:
	assert_true(BuildingTypeManager.has_capacity(GameConfig.container_type_id), "容器类型应有容量属性")

func test_has_capacity_for_pipe() -> void:
	assert_false(BuildingTypeManager.has_capacity(GameConfig.pipe_type_id), "管道类型不应有容量属性")

func test_has_capacity_for_default() -> void:
	assert_false(BuildingTypeManager.has_capacity("default"), "默认类型不应有容量属性")

func test_has_capacity_for_other_types() -> void:
	assert_false(BuildingTypeManager.has_capacity("type_04"), "type_04 不应有容量属性")
	assert_false(BuildingTypeManager.has_capacity("type_10"), "type_10 不应有容量属性")

func test_is_pipe_or_buffer_for_container() -> void:
	assert_true(BuildingTypeManager.is_pipe_or_buffer(GameConfig.container_type_id), "容器应为管道或缓存节点")

func test_is_pipe_or_buffer_for_pipe() -> void:
	assert_true(BuildingTypeManager.is_pipe_or_buffer(GameConfig.pipe_type_id), "管道应为管道或缓存节点")

func test_is_pipe_or_buffer_for_default() -> void:
	assert_false(BuildingTypeManager.is_pipe_or_buffer("default"), "默认类型不应为管道或缓存节点")

func test_undo_command_place_type() -> void:
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {
		Vector2i(0, 0): {"type": "type_01"}
	}
	assert_eq(cmd.type, UndoCommand.Type.PLACE, "类型应为 PLACE")
	assert_eq(cmd.buildings.size(), 1, "应包含一个建筑记录")

func test_undo_command_cut_type_as_dict() -> void:
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {
		Vector2i(2, 3): {
			"type": "type_01"
		}
	}
	assert_eq(cmd.type, UndoCommand.Type.CUT, "类型应为 CUT")
	assert_eq(cmd.buildings.size(), 1)

func test_undo_command_reverse_adds_building() -> void:
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.REMOVE
	cmd.buildings = {
		Vector2i(10, 20): {"type": "type_01"}
	}

	var bm: BuildingManager = _setup_bm()
	cmd.reverse(bm)
	assert_true(bm.has_building(Vector2i(10, 20)), "reverse 应在指定位置放置建筑")

func test_undo_command_reverse_place_removes_building() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	assert_true(bm.has_building(Vector2i(5, 5)), "放置后应有建筑")
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {Vector2i(5, 5): {"type": GameConfig.container_type_id}}
	cmd.reverse(bm)
	assert_false(bm.has_building(Vector2i(5, 5)), "reverse PLACE 应删除建筑")

func test_undo_command_reverse_cut_restores_building() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(3, 3), GameConfig.container_type_id)
	assert_true(bm.has_building(Vector2i(3, 3)), "放置后应有建筑")
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(3, 3): {"type": GameConfig.container_type_id}}
	bm.remove_building(Vector2i(3, 3))
	assert_false(bm.has_building(Vector2i(3, 3)), "删除后不应有建筑")
	cmd.reverse(bm)
	assert_true(bm.has_building(Vector2i(3, 3)), "reverse CUT 应恢复建筑")

func test_undo_command_reverse_cut_does_not_restore_capacity() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(8, 8), GameConfig.container_type_id, {"capacity": 50, "max_capacity": 100})
	assert_true(bm.has_building(Vector2i(8, 8)), "放置后应有建筑")
	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(8, 8): {"type": GameConfig.container_type_id}}
	bm.remove_building(Vector2i(8, 8))
	cmd.reverse(bm)
	assert_true(bm.has_building(Vector2i(8, 8)), "reverse CUT 应恢复建筑")
	var node: Node = bm.get_building_node(Vector2i(8, 8))
	assert_not_null(node, "恢复后节点应存在")
	assert_true(node is ContainerNode, "恢复后应为容器节点")
	var container: ContainerNode = node as ContainerNode
	assert_eq(container.capacity, 0, "撤销不应保留 capacity，应使用默认值 0")
	assert_eq(container.max_capacity, 100, "撤销不应保留 max_capacity，应使用默认值 100")

func test_is_container_building_with_container() -> void:
	var node: ContainerNode = autoqfree(_ContainerNode.new())
	assert_true(BuildingTypeManager.is_container_node(node), "ContainerNode 应判定为容器建筑")

func test_is_container_building_with_other() -> void:
	var node: Node2D = autoqfree(Node2D.new())
	assert_false(BuildingTypeManager.is_container_node(node), "普通 Node2D 不应判定为容器建筑")

func test_is_container_building_with_pipe() -> void:
	var node: PipeNode = autoqfree(_PipeNodeScript.new())
	assert_false(BuildingTypeManager.is_container_node(node), "PipeNode 不应判定为容器建筑")

func test_is_container_building_with_null() -> void:
	assert_false(BuildingTypeManager.is_container_node(null), "null 不应判定为容器建筑")

func test_undo_command_forward_remove() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	assert_true(bm.has_building(Vector2i(5, 5)), "放置后应有建筑")

	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.REMOVE
	cmd.buildings = {Vector2i(5, 5): {"type": GameConfig.container_type_id}}
	cmd.forward(bm)

	assert_false(bm.has_building(Vector2i(5, 5)), "forward REMOVE 应删除建筑")

func test_undo_command_forward_cut() -> void:
	var bm: BuildingManager = _setup_bm()
	bm.place_building(Vector2i(5, 5), GameConfig.container_type_id)
	assert_true(bm.has_building(Vector2i(5, 5)), "放置后应有建筑")

	var cmd: UndoCommand = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {Vector2i(5, 5): {"type": GameConfig.container_type_id}}
	cmd.forward(bm)

	assert_false(bm.has_building(Vector2i(5, 5)), "forward CUT 应删除建筑")
