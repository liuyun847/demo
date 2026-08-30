class_name MachineNode
extends BuildingBase

## 通用机器节点：按 MachineSpec 端口布局绘制（面朝方向 + 输入/输出口提示 + 类型字形），
## 配置状态（操作选择/分流轮询相位/按方向过滤条件）与 BuildingData 同步（由数据同步服务负责）。

var building_type: String = "default"
var direction: int = MachineSpec.DIR_E
var op_choice: int = -1
var splitter_phase: int = 0
var splitter_in_phase: int = 0
## 分流器按输出方向独立的过滤条件（下标=方向 0东1南2西3北；空字典 = 无条件放行）
var splitter_filters: Array = [{}, {}, {}, {}]

const GLYPHS: Dictionary = {
	MachineSpec.KIND_NUM_SOURCE: "1",
	MachineSpec.KIND_APPLIER: "f",
	MachineSpec.KIND_SPLITTER: "⇄",
	MachineSpec.KIND_BELT_SPLITTER: "⇄",
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

func set_splitter_filter(dir: int, cond: Dictionary) -> void:
	var d := clampi(dir, 0, 3)
	while splitter_filters.size() < 4:
		splitter_filters.append({})
	splitter_filters[d] = cond.duplicate(true)
	queue_redraw()

func set_splitter_filters(filters: Array) -> void:
	# 防御：不足 4 方向补空条件，超出裁剪
	splitter_filters = [{}, {}, {}, {}]
	for dir in range(mini(filters.size(), 4)):
		var cond: Variant = filters[dir]
		splitter_filters[dir] = cond.duplicate(true) if cond is Dictionary else {}
	queue_redraw()

func set_splitter_phase(phase: int) -> void:
	splitter_phase = phase

func set_splitter_in_phase(phase: int) -> void:
	splitter_in_phase = phase

func get_building_name() -> String:
	return MachineSpec.get_display_name(building_type)

func get_tooltip_summary() -> Dictionary:
	var kind := get_kind()
	var summary := {"name": get_building_name()}
	match kind:
		MachineSpec.KIND_NUM_SOURCE:
			summary["行为"] = "每 tick 产 1：无方向，自动向四周相邻传送带/贴脸机器输出（北→东→南→西优先，被占换向）"
		MachineSpec.KIND_APPLIER:
			summary["行为"] = "2入1出：数据口(半圆)+操作口(方) → 结果；操作口放数字 n = 数据 + n"
		MachineSpec.KIND_SPLITTER:
			summary["行为"] = "四向分流：任意口进出，均分轮询，被占自动换向不阻塞"
			var filter_text := _splitter_filter_text()
			if not filter_text.is_empty():
				summary["过滤"] = filter_text
				summary["操作"] = "点击打开配置面板"
		MachineSpec.KIND_BELT_SPLITTER:
			summary["行为"] = "四向分流：任意口进出，均分轮询，被占自动换向不阻塞"
		MachineSpec.KIND_TRASH:
			summary["行为"] = "传送带送入/贴脸投递即销毁；不从旁格主动吸取"
	return summary

## 分流器过滤摘要（有条件时逐方向列出，如 "东:>0 南:无 西:@取反 北:无"；全无条件返回空串）
func _splitter_filter_text() -> String:
	var dir_names := ["东", "南", "西", "北"]
	var parts: Array[String] = []
	var any := false
	for dir in range(mini(splitter_filters.size(), 4)):
		var cond: Variant = splitter_filters[dir]
		if cond is Dictionary and not (cond as Dictionary).is_empty():
			any = true
			parts.append("%s:%s" % [dir_names[dir], _cond_text(cond as Dictionary)])
		else:
			parts.append("%s:无" % dir_names[dir])
	return "" if not any else " ".join(parts)

func _cond_text(cond: Dictionary) -> String:
	if cond.get("kind", "") == "op":
		return "@%s" % OpRegistry.op_name(int(cond.get("value", -1)))
	var cmp := str(cond.get("cmp", "gt"))
	var op_text := "=" if cmp == "eq" else ("≠" if cmp == "ne" else ("<" if cmp == "lt" else ">"))
	return "数字 %s %d" % [op_text, int(cond.get("value", 0))]

func _draw() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var size := float(GameConfig.BUILDING_SIZE)
	var color: Color = MachineSpec.get_color(building_type)
	var kind := get_kind()
	# 底色
	draw_rect(Rect2(-half, -half, size, size), Color(color, 0.7))
	draw_rect(Rect2(-half, -half, size, size), Color(0.2, 0.2, 0.2), false, 2.0)
	# 朝向指示：前端画小三角（垃圾桶无输出/方向语义、数字源/四向分流器无方向，不画）
	if kind != MachineSpec.KIND_TRASH and kind != MachineSpec.KIND_NUM_SOURCE and kind != MachineSpec.KIND_SPLITTER:
		_draw_facing_marker(color)
	# 输入/输出端口提示（世界偏移换算到本地：端口格中心 - 本格中心）
	var ins: Array[Vector2i] = MachineSpec.get_ins(building_type, direction)
	var outs: Array[Vector2i] = MachineSpec.get_outs(building_type, direction)
	if kind == MachineSpec.KIND_APPLIER:
		# 应用器：输入口角色形状标记（数据口=半圆，操作口=方），画在机器本体内部对应
		# 端口一侧（端口格中心常被物品覆盖，机器内恒定可见）；端口位置仍由小点指示
		_draw_input_role_marker(ins[MachineSpec.APPLIER_IN_DATA], true)
		_draw_input_role_marker(ins[MachineSpec.APPLIER_IN_OP], false)
	# 四向分流器（含一体建筑）：不画输入/输出小孔与连接环，改画四向十字骨架
	# （格心到 4 边中点短线）+ 中心白环提示"任意口进出"；方向对称无固定输入输出；
	# 设了过滤条件的方向边中点画黄色小环
	var bm := get_parent() as BuildingManager
	if kind == MachineSpec.KIND_SPLITTER or kind == MachineSpec.KIND_BELT_SPLITTER:
		_draw_four_way_ports()
		_draw_port_ring(Vector2i.ZERO, Color(1, 1, 1, 0.7))
	else:
		for p: Vector2i in ins:
			_draw_port(p, true)
		for p: Vector2i in outs:
			_draw_port(p, false)
		# 数字源（无方向）：四边中点画白色小圆点 = 四向输出候选（替代原固定东侧输出口）
		if kind == MachineSpec.KIND_NUM_SOURCE:
			for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				_draw_port(off, false)
		# 端口连接高亮：输入口已被喂入 → 绿环；输出口有承接 → 白环
		if bm != null:
			for p: Vector2i in ins:
				if _is_input_fed(bm, grid_position + p):
					_draw_port_ring(p, Color(0.5, 1.0, 0.6, 0.95))
			for p: Vector2i in outs:
				if _is_output_received(bm, grid_position + p):
					_draw_port_ring(p, Color(1, 1, 1, 0.95))
	# 数字源（无方向）：任一相邻方向有承接（传送带/一体建筑格或贴脸对齐机器）
	# → 格中心白环，表示"正在自动连接"（无承接则不亮，指引玩家放传送带）
	if kind == MachineSpec.KIND_NUM_SOURCE and _num_source_has_any_output(bm):
		_draw_port_ring(Vector2i.ZERO, Color(1, 1, 1, 0.95))
	# 垃圾桶：有带子指向本体格（传送带输入）或贴脸机器投递 → 格中心绿环
	# （指示"有输入通道"，与数字源白环同款语义；无输入则不亮）
	if kind == MachineSpec.KIND_TRASH and _trash_has_any_input(bm):
		_draw_port_ring(Vector2i.ZERO, Color(0.5, 1.0, 0.6, 0.95))
	# 类型字形
	if GLYPHS.has(kind):
		_draw_glyph(GLYPHS[kind], color)

## 数字源（无方向）是否有输出承接：四周任一传送带/一体建筑格，或输入口正对本格的
## 贴脸对齐机器。仅作"已连接"指示（不等价于模拟器可投判定：不检查目标格/面槽空闲，
## 背压等待时白环仍亮），引导玩家放置传送带承接。
func _num_source_has_any_output(bm: BuildingManager) -> bool:
	if bm == null:
		return false
	for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = grid_position + off
		var other: BuildingData = bm.get_building_data(neighbor)
		if other == null:
			continue
		if MachineSpec.is_belt(other.building_type) or MachineSpec.is_belt_splitter(other.building_type):
			return true
		if MachineSpec.is_machine(other.building_type) and not MachineSpec.is_belt_splitter(other.building_type):
			if MachineSpec.get_ins(other.building_type, other.direction).has(-off):
				return true
	return false

## 垃圾桶是否有输入通道：带子出口正对本格（物品可推进垃圾桶本体格）、
## 一体建筑邻接（其四向输出可向垃圾桶贴脸投递，无条件可用）、或贴脸机器
## （数字源四邻/其他机器输出口）正对本格投递。仅作"已连接"指示。
func _trash_has_any_input(bm: BuildingManager) -> bool:
	if bm == null:
		return false
	for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var neighbor: Vector2i = grid_position + off
		var other: BuildingData = bm.get_building_data(neighbor)
		if other == null:
			continue
		if MachineSpec.is_belt(other.building_type) or MachineSpec.is_belt_splitter(other.building_type):
			# 带子：出口正对本格才可推入；一体建筑：自身不做传送带移动，但
			# 四向输出可向贴脸垃圾桶面槽投递（垃圾桶 ins 恒对齐）→ 无条件有通道
			if MachineSpec.is_belt_splitter(other.building_type):
				return true
			if other.direction == BeltConnection.offset_to_dir(-off):
				return true
		elif MachineSpec.is_machine(other.building_type) and not MachineSpec.is_belt_splitter(other.building_type):
			if MachineSpec.get_kind(other.building_type) == MachineSpec.KIND_NUM_SOURCE:
				return true  # 数字源无方向：贴脸即投
			# 其他机器输出口正对本格（0 格贴脸直传）
			if MachineSpec.get_outs(other.building_type, other.direction).has(-off):
				return true
	return false

## 输入口是否已连接：带子贴口（供料/顺带抽取）或贴面对齐机器/邻接机器输出口重合
func _is_input_fed(bm: BuildingManager, port_cell: Vector2i) -> bool:
	var other: BuildingData = bm.get_building_data(port_cell)
	if other == null:
		return false
	if MachineSpec.is_belt(other.building_type) or MachineSpec.is_belt_splitter(other.building_type):
		# 垃圾桶输入=本体格（带子推入）与面槽（贴脸投递），端口格不承接：
		# 带子贴端口格不算喂入，不画端口绿环（本体格输入由 _trash_has_any_input 指示）
		if get_kind() == MachineSpec.KIND_TRASH:
			return false
		return true
	if MachineSpec.is_machine(other.building_type) and not MachineSpec.is_belt_splitter(other.building_type):
		if MachineSpec.get_kind(other.building_type) == MachineSpec.KIND_NUM_SOURCE:
			# 数字源无方向：无固定输出口（outs 为空），只要本机器输入口正对源格即视为被喂入
			return MachineSpec.get_ins(building_type, direction).has(port_cell - grid_position)
		# 对方输出口正对本机器格（0 格贴脸直传）
		return MachineSpec.get_outs(other.building_type, other.direction).has(grid_position - port_cell) \
			and MachineSpec.get_ins(building_type, direction).has(port_cell - grid_position)
	return false

## 输出口是否已连接：带子承接，或贴面对齐机器（其输入口正对本机器格）
func _is_output_received(bm: BuildingManager, port_cell: Vector2i) -> bool:
	var other: BuildingData = bm.get_building_data(port_cell)
	if other == null:
		return false
	if MachineSpec.is_belt(other.building_type) or MachineSpec.is_belt_splitter(other.building_type):
		return true
	if MachineSpec.is_machine(other.building_type) and not MachineSpec.is_belt_splitter(other.building_type):
		return MachineSpec.get_ins(other.building_type, other.direction).has(grid_position - port_cell)
	return false

func _draw_port_ring(offset: Vector2i, color: Color, radius: float = 8.0) -> void:
	var local_center := Vector2(offset.x, offset.y) * float(GameConfig.CELL_SIZE)
	draw_arc(local_center, radius, 0.0, TAU, 24, color, 2.0)

## 朝向标记：前端小三角
func _draw_facing_marker(_color: Color) -> void:
	var front_offset := MachineSpec.dir_to_offset(direction)
	var center := front_offset * float(GameConfig.BUILDING_SIZE / 2.0 - 6.0)
	# 简化：直接画一个小圆点表示前端
	draw_circle(center, 3.0, Color(1, 1, 1, 0.9))

## 四向分流器端口骨架：格心到 4 边中点画短线 + 边中点小白点（对称，不区分进出）；
## 设了过滤条件的方向边中点加画黄色小环（一眼看出哪边设了过滤）
func _draw_four_way_ports() -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	for dir in range(4):
		var off: Vector2i = MachineSpec.FOUR_WAY_PORTS[dir]
		var dv := Vector2(off)
		draw_line(dv * (half * 0.3), dv * (half - 2.0), Color(0.95, 0.95, 1.0, 0.75), 4.0)
		draw_circle(dv * (half - 2.0), 4.0, Color(1, 1, 1, 0.85))
		if _dir_has_filter(dir):
			_draw_port_ring(off, Color(1.0, 0.85, 0.2, 0.95), 7.0)

## 方向是否设了过滤条件（索引越界/非字典 = 无条件）
func _dir_has_filter(dir: int) -> bool:
	if dir < 0 or dir >= splitter_filters.size():
		return false
	var cond: Variant = splitter_filters[dir]
	return cond is Dictionary and not (cond as Dictionary).is_empty()

## 端口提示：输入=黑色小孔，输出=白色小孔
func _draw_port(offset: Vector2i, is_input: bool) -> void:
	var local_center := Vector2(offset.x, offset.y) * float(GameConfig.CELL_SIZE)
	draw_circle(local_center, 5.0, Color(0.05, 0.05, 0.05, 0.85) if is_input else Color(1, 1, 1, 0.85))
	if not is_input:
		draw_circle(local_center, 2.0, Color(0.2, 0.2, 0.2))

## 应用器输入口角色标记：数据口=半圆（平边朝机器外缘），操作口=方。
## 画在机器本体内部、对应端口一侧，主色填充 + 深色描边（风格对齐物品色块 ItemShape）。
func _draw_input_role_marker(offset: Vector2i, is_data: bool) -> void:
	var half := GameConfig.BUILDING_SIZE / 2.0
	var center := Vector2(offset.x, offset.y) * (half - 10.0)
	var color: Color = MachineSpec.get_color(building_type)
	var border := Color(0.1, 0.1, 0.1, 0.9)
	if is_data:
		# 半圆：平边靠近机器外缘，拱顶指向机器内部（dome 沿 -offset 方向）
		var inward := Vector2(-offset.x, -offset.y).normalized()
		var rot := atan2(inward.y, inward.x) + PI / 2.0
		var pts: PackedVector2Array = []
		for i in range(13):
			var t := PI * float(i) / 12.0
			pts.append(center + Vector2(8.0 * cos(t), -8.0 * sin(t)).rotated(rot))
		draw_colored_polygon(pts, color)
		draw_polyline(pts, border, 2.0)
		draw_line(pts[0], pts[12], border, 2.0)
	else:
		var side := 8.0 * 1.7
		var rect := Rect2(center.x - side / 2.0, center.y - side / 2.0, side, side)
		draw_rect(rect, color)
		draw_rect(rect, border, false, 2.0)

func _draw_glyph(glyph: String, _color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 20
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, -text_size / 2.0, glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.1, 0.1, 0.1, 0.85))