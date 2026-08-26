class_name MachineConfigPanel
extends PanelContainer

## 机器配置面板：筛选器设谓词（Mode.FILTER）。
## 代码构建（不依赖 .tscn），放置后/点击机器时由输入处理器打开。

enum Mode { FILTER }

var target: MachineNode = null
var mode: Mode = Mode.FILTER

const PANEL_SIZE := Vector2(260, 200)

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
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "筛选器配置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 16
	ls.font_color = Color.WHITE
	title.label_settings = ls
	box.add_child(title)

	_build_filter_content(box)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close)
	box.add_child(close_btn)

func _build_filter_content(box: VBoxContainer) -> void:
	var kind_row := HBoxContainer.new()
	var kind_label := Label.new()
	kind_label.text = "类型:"
	kind_label.custom_minimum_size = Vector2(60, 30)
	kind_row.add_child(kind_label)
	var kind_option := OptionButton.new()
	kind_option.add_item("数字", 0)
	kind_option.add_item("操作", 1)
	if target != null:
		kind_option.select(1 if target.filter_kind == "op" else 0)
	kind_option.item_selected.connect(_on_kind_selected)
	kind_row.add_child(kind_option)
	box.add_child(kind_row)

	var cmp_row := HBoxContainer.new()
	var cmp_label := Label.new()
	cmp_label.text = "比较:"
	cmp_label.custom_minimum_size = Vector2(60, 30)
	cmp_row.add_child(cmp_label)
	var cmp_option := OptionButton.new()
	cmp_option.add_item(">")
	cmp_option.add_item("<")
	cmp_option.add_item("=")
	cmp_option.add_item("≠")
	cmp_option.selected = _cmp_index(target.filter_cmp if target != null else "gt")
	cmp_option.item_selected.connect(_on_cmp_selected)
	cmp_row.add_child(cmp_option)
	box.add_child(cmp_row)

	var value_row := HBoxContainer.new()
	var value_label := Label.new()
	value_label.text = "数值:"
	value_label.custom_minimum_size = Vector2(60, 30)
	value_row.add_child(value_label)
	var spin := SpinBox.new()
	spin.min_value = -999999
	spin.max_value = 999999
	spin.set_value_no_signal(float(target.filter_value if target != null else 0))
	spin.value_changed.connect(_on_value_changed)
	value_row.add_child(spin)
	box.add_child(value_row)

	var hint := Label.new()
	hint.text = "匹配走前口(通过)，不匹配走侧口(拒绝)"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(hint)

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

func _on_kind_selected(idx: int) -> void:
	if target == null:
		return
	target.filter_kind = "op" if idx == 1 else "num"
	_apply_filter()

func _on_cmp_selected(idx: int) -> void:
	if target == null:
		return
	target.filter_cmp = _cmp_from_index(idx)
	_apply_filter()

func _on_value_changed(v: float) -> void:
	if target == null:
		return
	target.filter_value = int(v)
	_apply_filter()

func _apply_filter() -> void:
	if target == null:
		return
	target.set_filter(target.filter_kind, target.filter_cmp, target.filter_value)
	EventBus.machine_config_changed.emit(target.grid_position)

func _close() -> void:
	if is_instance_valid(self):
		queue_free()