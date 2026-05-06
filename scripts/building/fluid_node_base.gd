class_name FluidNodeBase
extends Node2D

@export var grid_position: Vector2i

func get_pressure() -> float:
	push_error("必须由子类实现")
	return 0.0

func collect_transfers(_transfers: Array[Dictionary]) -> void:
	pass
