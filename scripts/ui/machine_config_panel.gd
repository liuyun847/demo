class_name MachineConfigPanel
extends PanelContainer

## 机器配置面板：分流器按方向设置过滤条件（Mode.SPLITTER）。
## 代码构建（不依赖 .tscn），放置后/点击分流器时由输入处理器打开。
## 每个输出方向可独立设置：无条件 / 数字比较 / 操作匹配；
## 物品只能走"无条件或条件匹配"的方向，全部不匹配 = 背压等待（物品不丢）。

enum Mode { SPLITTER }

var target: MachineNode = null
var mode: Mode = Mode.SPLITTER

## 面板尺寸：4 行方向配置（每行含类型/比较/数值/操作控件）
const PANEL_SIZE := Vector2(320, 380)

## 方向展示顺序 = MachineSpec.FOUR_WAY_PORTS（0东1南2西3北，端口不随朝向旋转）
const DIR_NAMES: Array[String] = ["东", "南", "西", "北"]

## 每方向的条件控件容器（kind_option 回调按 dir 索引更新可见性）
var _cond_boxes: Array[HBoxContainer] = []

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.96)
	style.border_color = Color(0.4, 0.6, 0.9, 0.8)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = PANEL_SIZE
	_build_content()
	position = Vector2(20, 20)

func _exit_tree() -> void:
	EventBus.config_panel_closed.emit()

func _build_content() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var title := Label.new()
	title.text = "分流器配置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 16
	ls.font_color = Color.WHITE
	title.label_settings = ls
	box.add_child(title)

	_build_splitter_content(box)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close)
	box.add_child(close_btn)

## 分流器内容：4 行方向条件 + 底部语义提示
func _build_splitter_content(box: VBoxContainer) -> void:
	if target == null:
		return
	_cond_boxes = [null, null, null, null]
	for dir in range(4):
		box.add_child(_build_dir_row(dir))
	var hint := Label.new()
	hint.text = "物品只能走无条件或条件匹配的方向；全部不匹配=滞留等待"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(hint)

## 单个方向行：方向标签 + 类型选择 + 条件控件（数字=比较+数值 / 操作=操作选择）
func _build_dir_row(dir: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var dir_label := Label.new()
	dir_label.text = DIR_NAMES[dir]
	dir_label.custom_minimum_size = Vector2(30, 30)
	dir_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(dir_label)

	var cond := _get_cond(dir)
	var kind := str(cond.get("kind", ""))

	# 类型：无条件 / 数字 / 操作（回调签名 _on_kind_selected(idx, dir)）
	var kind_option := OptionButton.new()
	kind_option.add_item("无条件", 0)
	kind_option.add_item("数字", 1)
	kind_option.add_item("操作", 2)
	kind_option.select(0 if kind.is_empty() else (1 if kind == "num" else 2))
	kind_option.item_selected.connect(_on_kind_selected.bind(dir))
	row.add_child(kind_option)

	# 条件控件容器（无条件时隐藏；引用存 _cond_boxes 供类型切换更新）
	var cond_box := _build_cond_controls(dir, cond)
	row.add_child(cond_box)
	_cond_boxes[dir] = cond_box
	_apply_cond_visibility(dir, kind)
	return row

## 条件控件：数字=比较(>/</=/≠)+数值 SpinBox；操作=操作 OptionButton；
## 控件引用挂 cond_box meta，供类型切换时按 kind 控制可见性
func _build_cond_controls(dir: int, cond: Dictionary) -> HBoxContainer:
	var cond_box := HBoxContainer.new()
	cond_box.add_theme_constant_override("separation", 4)

	var cmp_option := OptionButton.new()
	cmp_option.add_item(">")
	cmp_option.add_item("<")
	cmp_option.add_item("=")
	cmp_option.add_item("≠")
	cmp_option.selected = _cmp_index(str(cond.get("cmp", "gt")))
	cmp_option.item_selected.connect(_on_cmp_selected.bind(dir))
	cond_box.add_child(cmp_option)

	var spin := SpinBox.new()
	spin.min_value = -999999
	spin.max_value = 999999
	spin.custom_minimum_size = Vector2(90, 30)
	spin.set_value_no_signal(float(int(cond.get("value", 0))))
	spin.value_changed.connect(_on_value_changed.bind(dir))
	cond_box.add_child(spin)

	var op_option := OptionButton.new()
	for op_id: int in OpRegistry.get_all_ids():
		op_option.add_item(OpRegistry.op_name(op_id), op_id)
	# 复合操作（存档/粘贴恢复）也在列；未知 id 回退第一项
	op_option.select(maxi(op_option.get_item_index(int(cond.get("value", OpRegistry.OP_ADD1))), 0))
	# 注意 item_selected 回调收到的是"索引"而非 id（复合操作 id≥100 时索引≠id），
	# 回调内须经 get_item_id(idx) 还原真正的操作 id（曾直接当 id 用导致复合条件写错）
	op_option.item_selected.connect(_on_op_selected.bind(dir, op_option))
	cond_box.add_child(op_option)

	cond_box.set_meta("num_controls", [cmp_option, spin])
	cond_box.set_meta("op_controls", [op_option])
	return cond_box

## 按类型显示对应控件：数字=比较+数值，操作=操作选择，无条件=全隐藏
func _apply_cond_visibility(dir: int, kind: String) -> void:
	if dir < 0 or dir >= _cond_boxes.size() or _cond_boxes[dir] == null:
		return
	var cond_box := _cond_boxes[dir]
	cond_box.visible = not kind.is_empty()
	for ctrl: Variant in cond_box.get_meta("num_controls", []):
		(ctrl as Control).visible = kind == "num"
	for ctrl: Variant in cond_box.get_meta("op_controls", []):
		(ctrl as Control).visible = kind == "op"

func _get_cond(dir: int) -> Dictionary:
	if target == null:
		return {}
	if dir < 0 or dir >= target.splitter_filters.size():
		return {}
	var cond: Variant = target.splitter_filters[dir]
	return cond as Dictionary if cond is Dictionary else {}

# ---------- 条件变更（写节点 + 触发同步/延迟存档） ----------

func _on_kind_selected(idx: int, dir: int) -> void:
	if target == null:
		return
	match idx:
		1:
			_set_cond(dir, {"kind": "num", "cmp": "gt", "value": _get_cond(dir).get("value", 0)})
			_apply_cond_visibility(dir, "num")
		2:
			# 切到操作类型时保留原 value（复合操作条件不因类型切换丢失）
			var keep := int(_get_cond(dir).get("value", OpRegistry.OP_ADD1))
			if not OpRegistry.has(keep):
				keep = OpRegistry.OP_ADD1
			_set_cond(dir, {"kind": "op", "value": keep})
			_apply_cond_visibility(dir, "op")
		_:
			_set_cond(dir, {})
			_apply_cond_visibility(dir, "")

func _on_cmp_selected(idx: int, dir: int) -> void:
	if target == null:
		return
	var cond := _get_cond(dir)
	if cond.is_empty():
		return
	cond["cmp"] = _cmp_from_index(idx)
	_set_cond(dir, cond)

func _on_value_changed(v: float, dir: int) -> void:
	if target == null:
		return
	var cond := _get_cond(dir)
	if cond.is_empty():
		return
	cond["value"] = int(v)
	_set_cond(dir, cond)

func _on_op_selected(idx: int, dir: int, op_option: OptionButton = null) -> void:
	if target == null:
		return
	# idx 是 OptionButton 项索引（item_selected 回调语义），须还原为操作 id；
	# 直接调用（测试）时无控件引用，按 id 处理
	var op_id: int = op_option.get_item_id(idx) if op_option != null else idx
	var cond := _get_cond(dir)
	cond["kind"] = "op"
	cond["value"] = op_id
	_set_cond(dir, cond)

func _set_cond(dir: int, cond: Dictionary) -> void:
	if target == null:
		return
	target.set_splitter_filter(dir, cond)
	EventBus.machine_config_changed.emit(target.grid_position)

func _cmp_index(cmp: String) -> int:
	match cmp:
		"lt":
			return 1
		"eq":
			return 2
		"ne":
			return 3
		_:
			return 0

func _cmp_from_index(idx: int) -> String:
	match idx:
		1:
			return "lt"
		2:
			return "eq"
		3:
			return "ne"
		_:
			return "gt"

func _close() -> void:
	if is_instance_valid(self):
		queue_free()
