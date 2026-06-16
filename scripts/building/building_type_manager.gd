class_name BuildingTypeManager
extends RefCounted

# 建筑类型注册表：key = type_id, value = BuildingTypeData
# BuildingTypeData 自描述行为元数据（has_capacity / is_pipe / ...）
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


static func has_capacity(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.has_capacity


static func is_pipe(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.is_pipe


static func is_emitter(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.is_emitter


static func is_collector(type_id: String) -> bool:
	var td: BuildingTypeData = _type_table.get(type_id) as BuildingTypeData
	return td != null and td.is_collector
