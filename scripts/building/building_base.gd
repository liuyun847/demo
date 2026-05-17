class_name BuildingBase
extends Node2D

var grid_position: Vector2i

func get_building_name() -> String:
	return "未知建筑"

func get_tooltip_summary() -> Dictionary:
	return {}

func get_tooltip_details() -> Dictionary:
	return {}
