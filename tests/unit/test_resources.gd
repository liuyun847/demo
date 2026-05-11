extends GutTest

func test_building_data_creation():
	var data = BuildingData.new()
	data.grid_position = Vector2i(3, 5)
	data.building_type = "type_01"
	data.capacity = 50
	data.max_capacity = 100

	assert_eq(data.grid_position, Vector2i(3, 5), "grid_position 应正确赋值")
	assert_eq(data.building_type, "type_01", "building_type 应正确赋值")
	assert_eq(data.capacity, 50, "capacity 应正确赋值")
	assert_eq(data.max_capacity, 100, "max_capacity 应正确赋值")

func test_building_data_defaults():
	var data = BuildingData.new()
	assert_eq(data.building_type, "default", "默认 building_type 应为 default")
	assert_eq(data.capacity, 0, "默认 capacity 应为 0")
	assert_eq(data.max_capacity, 100, "默认 max_capacity 应为 100")

func test_has_capacity_for_container():
	assert_true(BuildingData.has_capacity(GameConfig.container_type_id), "容器类型应有容量属性")

func test_has_capacity_for_pipe():
	assert_false(BuildingData.has_capacity(GameConfig.pipe_type_id), "管道类型不应有容量属性")

func test_has_capacity_for_water_source():
	assert_false(BuildingData.has_capacity(GameConfig.water_source_type_id), "水源类型不应有容量属性")

func test_has_capacity_for_default():
	assert_false(BuildingData.has_capacity("default"), "默认类型不应有容量属性")

func test_has_capacity_for_other_types():
	assert_false(BuildingData.has_capacity("type_04"), "type_04 不应有容量属性")
	assert_false(BuildingData.has_capacity("type_10"), "type_10 不应有容量属性")

func test_is_fluid_building_for_container():
	assert_true(BuildingData.is_fluid_building(GameConfig.container_type_id), "容器应为流体建筑")

func test_is_fluid_building_for_pipe():
	assert_true(BuildingData.is_fluid_building(GameConfig.pipe_type_id), "管道应为流体建筑")

func test_is_fluid_building_for_water_source():
	assert_true(BuildingData.is_fluid_building(GameConfig.water_source_type_id), "水源应为流体建筑")

func test_is_fluid_building_for_default():
	assert_false(BuildingData.is_fluid_building("default"), "默认类型不应为流体建筑")

func test_undo_command_place_type():
	var cmd = UndoCommand.new()
	cmd.type = UndoCommand.Type.PLACE
	cmd.buildings = {
		Vector2i(0, 0): "type_01"
	}
	assert_eq(cmd.type, UndoCommand.Type.PLACE, "类型应为 PLACE")
	assert_eq(cmd.buildings.size(), 1, "应包含一个建筑记录")

func test_undo_command_cut_type_with_capacity():
	var cmd = UndoCommand.new()
	cmd.type = UndoCommand.Type.CUT
	cmd.buildings = {
		Vector2i(2, 3): {
			"type": "type_01",
			"capacity": 30,
			"max_capacity": 100
		}
	}
	assert_eq(cmd.type, UndoCommand.Type.CUT, "类型应为 CUT")
	assert_eq(cmd.buildings.size(), 1)

func test_undo_command_reverse_adds_building():
	var cmd = UndoCommand.new()
	cmd.type = UndoCommand.Type.REMOVE
	cmd.buildings = {
		Vector2i(10, 20): "type_01"
	}

	var bm = autoqfree(BuildingManager.new())
	add_child_autoqfree(bm)
	cmd.reverse(bm)
	assert_true(bm.has_building(Vector2i(10, 20)), "reverse 应在指定位置放置建筑")
