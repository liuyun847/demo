class_name BeltNode
extends BuildingBase

## 传送带节点：持有朝向并绘制推进箭头。
## 朝向 (direction)：0东 1南 2西 3北（MachineSpec.DIR_*，与数据一致）。
## 物品推进由 ItemSimulator 负责，节点仅负责视觉。
## 视觉：底格 + 内槽 + 连接带（BeltConnection.compute 结果）——带子按邻居关系
## 绘制连续连接带（直线/转弯/T 接/端口供料），无连接信息时回退旧式方向箭头。

var direction: int = MachineSpec.DIR_E
var building_type: String = MachineSpec.T_BELT

func set_direction(dir: int) -> void:
	direction = (dir % 4 + 4) % 4
	queue_redraw()

func get_building_name() -> String:
	return "传送带"

func get_tooltip_summary() -> Dictionary:
	return {
		"name": "传送带",
		"行为": "每 tick 向箭头方向推进一格",
		"方向": "R 键旋转",
		"背压": "下一格被占则等待，物品不丢失",
	}

func _draw() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var size := float(GameConfig.BUILDING_SIZE)
	var color: Color = MachineSpec.get_color(MachineSpec.T_BELT)
	# 底色
	draw_rect(Rect2(-half, -half, size, size), Color(color, 0.35))
	draw_rect(Rect2(-half, -half, size, size), Color(0.2, 0.2, 0.2), false, 2.0)
	# 内槽（物品承载面）
	var inset := 10.0
	draw_rect(Rect2(-half + inset, -half + inset, size - inset * 2.0, size - inset * 2.0),
		Color(0.15, 0.15, 0.18, 0.6))
	# 连接带（从 BuildingManager 的连接缓存读取；无缓存时回退旧样式）
	var bm := get_parent() as BuildingManager
	var info: Dictionary = {}
	if bm != null:
		info = bm.belt_connections.get(grid_position, {})
	if info.is_empty():
		_draw_arrow(direction)
	else:
		BeltConnection.draw_band(self, info)

## 绘制旧式朝向箭头（三角形；无连接信息时的回退）
func _draw_arrow(dir: int) -> void:
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
