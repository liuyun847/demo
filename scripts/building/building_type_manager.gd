class_name BuildingTypeManager
extends RefCounted

# 建筑类型注册表：key = type_id, value = BuildingTypeData
# BuildingTypeData 自描述行为元数据（has_capacity / category）
# 注册由 inventory_bar._init_default_types() 在游戏启动时完成；
# 测试环境需在 before_all 中显式注册（详见 test_building_type_manager.gd）。
static var _type_table: Dictionary = {}


# 注册/更新单个类型
static func register(type_data: BuildingTypeData) -> void:
	if type_data == null or type_data.type_id.is_empty():
		return
	_type_table[type_data.type_id] = type_data


# 批量注册
static func register_all(type_datas: Array) -> void:
	for td: Variant in type_datas:
		if td is BuildingTypeData:
			register(td)


# 测试钩子：清空注册表（避免 static var 跨测试脏数据）
static func reset_for_test() -> void:
	_type_table.clear()


# 提前注册默认建筑类型，使用字符串字面量以避免 GameConfig 编译时依赖。
# 由 GameConfig._ready() 在启动早期调用，确保 SaveManager.load_buildings()
# 执行时 BuildingTypeManager 已就绪，工厂能正确识别各类建筑。
static func register_defaults() -> void:
	if not _type_table.is_empty():
		return
	var entries: Array[Dictionary] = [
		{"id": "type_02", "category": BuildingTypeData.Category.PIPE},
		{"id": "type_03", "category": BuildingTypeData.Category.SOURCE},
		{"id": "type_04", "category": BuildingTypeData.Category.BRICK},
		{"id": "type_07", "category": BuildingTypeData.Category.COLLECTOR},
	]
	for entry: Dictionary in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry["id"]
		td.category = entry["category"]
		register(td)


static func has_capacity(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.has_capacity


static func is_pipe(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.category == BuildingTypeData.Category.PIPE


static func is_source(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.category == BuildingTypeData.Category.SOURCE


static func is_collector(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.category == BuildingTypeData.Category.COLLECTOR


## 获取建筑类别（未注册时返回 GENERIC）
static func get_category(type_id: String) -> BuildingTypeData.Category:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	if td == null:
		return BuildingTypeData.Category.GENERIC
	return td.category


## 获取建筑颜色：default/type_00 返回默认色，type_01..type_10 按 HSV 色环均匀分布
static func get_building_color(building_type: String) -> Color:
	if building_type == "default" or building_type.is_empty():
		return GameConfig.BUILDING_DEFAULT_COLOR
	if building_type.begins_with("type_"):
		var idx := building_type.substr(5).to_int()
		if idx >= 1 and idx <= 10:
			return Color.from_hsv(float(idx - 1) / 10.0, 0.7, 0.9)
	return GameConfig.BUILDING_DEFAULT_COLOR
