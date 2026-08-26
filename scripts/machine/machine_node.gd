class_name MachineNode
extends BuildingBase

## 通用机器节点：按 MachineSpec 端口布局绘制（面朝方向 + 输入/输出口提示 + 类型字形），
## 配置状态（操作选择/筛选谓词/分流交替位）与 BuildingData 同步（由数据同步服务负责）。

var building_type: String = "default"
var direction: int = MachineSpec.DIR_E
var op_choice: int = -1
var filter_kind: String = "num"
var filter_cmp: String = "gt"
var filter_value: int = 0
var splitter_phase: int = 0

const GLYPHS: Dictionary = {
	MachineSpec.KIND_NUM_SOURCE: "1",
	MachineSpec.KIND_APPLIER: "f",
	MachineSpec.KIND_SPLITTER: "⇄",
	MachineSpec.KIND_BELT_SPLITTER: "⇄",
	MachineSpec.KIND_FILTER: "?",
	MachineSpec.KIND_TRASH: "✕",
}

func get_kind() -> String:
	return MachineSpec.get_kind(building_type)

func set_direction(dir: int) -> void:
	direction = (dir % 4 + 4) % 4
	queue_redraw()

func set_op_choice(op_id: int) -> void:
	op_choice = op_id
	queue_redraw()

func set_filter(kind: String, cmp: String, value: int) -> void:
	filter_kind = kind
	filter_cmp = cmp
	filter_value = value
	queue_redraw()

func set_splitter_phase(phase: int) -> void:
	splitter_phase = phase

func get_building_name() -> String:
	return MachineSpec.get_display_name(building_type)

func get_tooltip_summary() -> Dictionary:
	var kind := get_kind()
	var summary := {"name": get_building_name()}
	match kind:
		MachineSpec.KIND_NUM_SOURCE:
			summary["行为"] = "每 tick 产 1（出口空才产）"
		MachineSpec.KIND_APPLIER:
			summary["行为"] = "2入1出：(op, data) → 结果"
		MachineSpec.KIND_SPLITTER:
			summary["行为"] = "1入2出：交替分流"
		MachineSpec.KIND_FILTER:
			summary["行为"] = "匹配走前口，否则走侧口"
			summary["当前"] = _filter_text()
			summary["操作"] = "点击打开配置面板"
		MachineSpec.KIND_TRASH:
			summary["行为"] = "删除输入物品"
	return summary

func _filter_text() -> String:
	if filter_kind == "op":
		return "@%s" % OpRegistry.op_name(filter_value)
	var op_text := "=" if filter_cmp == "eq" else ("≠" if filter_cmp == "ne" else ("<" if filter_cmp == "lt" else ">"))
	return "数字 %s %d" % [op_text, filter_value]

func _draw() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var size := float(GameConfig.BUILDING_SIZE)
	var color: Color = MachineSpec.get_color(building_type)
	var kind := get_kind()
	# 底色
	draw_rect(Rect2(-half, -half, size, size), Color(color, 0.7))
	draw_rect(Rect2(-half, -half, size, size), Color(0.2, 0.2, 0.2), false, 2.0)
	# 朝向指示：前端画小三角
	_draw_facing_marker(color)
	# 输入/输出端口提示（世界偏移换算到本地：端口格中心 - 本格中心）
	var ins: Array[Vector2i] = MachineSpec.get_ins(building_type, direction)
	var outs: Array[Vector2i] = MachineSpec.get_outs(building_type, direction)
	for p: Vector2i in ins:
		_draw_port(p, true)
	for p: Vector2i in outs:
		_draw_port(p, false)
	# 类型字形
	if GLYPHS.has(kind):
		_draw_glyph(GLYPHS[kind], color)

## 朝向标记：前端小三角
func _draw_facing_marker(_color: Color) -> void:
	var front_offset := MachineSpec.dir_to_offset(direction)
	var center := front_offset * float(GameConfig.BUILDING_SIZE / 2.0 - 6.0)
	# 简化：直接画一个小圆点表示前端
	draw_circle(center, 3.0, Color(1, 1, 1, 0.9))

## 端口提示：输入=黑色小孔，输出=白色小孔
func _draw_port(offset: Vector2i, is_input: bool) -> void:
	var local_center := Vector2(offset.x, offset.y) * float(GameConfig.CELL_SIZE)
	draw_circle(local_center, 5.0, Color(0.05, 0.05, 0.05, 0.85) if is_input else Color(1, 1, 1, 0.85))
	if not is_input:
		draw_circle(local_center, 2.0, Color(0.2, 0.2, 0.2))

func _draw_glyph(glyph: String, _color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 20
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, -text_size / 2.0, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.1, 0.1, 0.1, 0.85))