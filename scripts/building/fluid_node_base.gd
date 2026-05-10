class_name FluidNodeBase
extends Node2D

@export var grid_position: Vector2i

func get_pressure() -> float:
	push_error("必须由子类实现")
	return 0.0

func get_building_name() -> String:
	return "未知建筑"

func get_tooltip_summary() -> Dictionary:
	return {}

func get_tooltip_details() -> Dictionary:
	return {}
