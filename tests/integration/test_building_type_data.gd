extends GutTest

func test_create_building_type_data() -> void:
	var data: BuildingTypeData = BuildingTypeData.new()
	data.type_id = "type_01"
	data.display_name = "容器"
	assert_eq(data.type_id, "type_01", "type_id 应被正确赋值")
	assert_eq(data.display_name, "容器", "display_name 应被正确赋值")

func test_building_type_data_extends_resource() -> void:
	var data: BuildingTypeData = BuildingTypeData.new()
	assert_true(data is Resource, "BuildingTypeData 应继承自 Resource")

func test_exported_properties_exist() -> void:
	var data: BuildingTypeData = BuildingTypeData.new()
	assert_eq(data.get("type_id"), "", "默认 type_id 应为空字符串")
	assert_eq(data.get("display_name"), "", "默认 display_name 应为空字符串")
	assert_eq(data.get("icon_texture"), null, "默认 icon_texture 应为 null")
