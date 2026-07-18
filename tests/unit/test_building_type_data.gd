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
	assert_eq(data.get("has_capacity"), false, "默认 has_capacity 应为 false")
	# category 默认应为 GENERIC（枚举化后新增的属性）
	assert_eq(data.get("category"), BuildingTypeData.Category.GENERIC, "默认 category 应为 GENERIC")

## category 枚举化后新增测试：所有枚举值可正常赋值与读取
func test_category_enum_assignable() -> void:
	var data: BuildingTypeData = BuildingTypeData.new()
	var cats: Array[BuildingTypeData.Category] = [
		BuildingTypeData.Category.GENERIC,
		BuildingTypeData.Category.PIPE,
		BuildingTypeData.Category.SOURCE,
		BuildingTypeData.Category.COLLECTOR,
		BuildingTypeData.Category.BRICK,
	]
	for cat: BuildingTypeData.Category in cats:
		data.category = cat
		assert_eq(data.category, cat, "category 应能正确赋值与读取: %d" % cat)
