class_name BeltSplitterNode
extends MachineNode

## 传送带+分流器一体建筑节点（分流器放在传送带上时自动转换）。
## 视觉=传送带底（底色/内槽/方向箭头）+ 分流器盒体（复用 MachineNode 绘制）。
## 物品流由 ItemSimulator 处理：物品经上游带流入本格，分流器交替送前/左口。

func _init() -> void:
	building_type = MachineSpec.T_BELT_SPLITTER

## 一体建筑的工具提示：注明自带传送带层
func get_tooltip_summary() -> Dictionary:
	var summary := super.get_tooltip_summary()
	summary["行为"] = "装在传送带上：交替分流（前口/左口）"
	summary["传送带"] = "物品沿带流入本格，分流后继续流动"
	return summary

func _draw() -> void:
	_build_belt_base()
	super._draw()

## 传送带底：与 BeltNode 同风格（底色 + 内槽 + 方向箭头）
func _build_belt_base() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var size := float(GameConfig.BUILDING_SIZE)
	var color: Color = MachineSpec.get_color(MachineSpec.T_BELT)
	draw_rect(Rect2(-half, -half, size, size), Color(color, 0.55))
	draw_rect(Rect2(-half, -half, size, size), Color(0.2, 0.2, 0.2), false, 2.0)
	var inset := 10.0
	draw_rect(Rect2(-half + inset, -half + inset, size - inset * 2.0, size - inset * 2.0),
		Color(0.15, 0.15, 0.18, 0.6))
	_draw_direction_arrow(direction)

## 方向箭头（三角形，复制 BeltNode 视角；后续可提取共用，暂且保持独立）
func _draw_direction_arrow(dir: int) -> void:
	var tip := Vector2.ZERO
	var base_dir := Vector2.ZERO
	match dir:
		MachineSpec.DIR_E:
			tip = Vector2(14, 0)
			base_dir = Vector2(-14, 0)
		MachineSpec.DIR_S:
			tip = Vector2(0, 14)
			base_dir = Vector2(0, -14)
		MachineSpec.DIR_W:
			tip = Vector2(-14, 0)
			base_dir = Vector2(14, 0)
		_:
			tip = Vector2(0, -14)
			base_dir = Vector2(0, 14)
	var left_wing := base_dir.rotated(-0.5).normalized() * 10.0
	var right_wing := base_dir.rotated(0.5).normalized() * 10.0
	var a := tip + left_wing
	var b := tip + right_wing
	draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(0.9, 0.9, 0.95, 0.95))
