class_name BuildingTypeData
extends Resource

@export var type_id: String
@export var display_name: String
@export var icon_texture: Texture2D
# 类型行为元数据（数据驱动，BuildingTypeManager 通过查询 type_id 获取这些属性）
@export var has_capacity: bool = false
@export var is_pipe: bool = false
@export var is_emitter: bool = false
@export var is_collector: bool = false
