## 流体节点基类，所有流体建筑（容器、管道、水源）继承自此基类。
## 子类必须实现 get_pressure() 等抽象方法。
class_name FluidNodeBase
extends Node2D

var grid_position: Vector2i

## 抽象方法：返回当前节点的压力值，子类必须实现。
func get_pressure() -> float:
	push_error("必须由子类实现")
	return 0.0

func get_building_name() -> String:
	return "未知建筑"

func get_tooltip_summary() -> Dictionary:
	return {}

func get_tooltip_details() -> Dictionary:
	return {}
