class_name ElementTypeData
extends Resource

@export var element_id: String
@export var display_name: String
@export var color: Color
@export var density: float = 1.0          ## 密度，反应时密度大的格子优先成为产物位置
@export var state: String = "liquid"      ## 物态: "liquid" | "gas" | "solid"
@export var reactive: bool = true         ## 是否参与反应
