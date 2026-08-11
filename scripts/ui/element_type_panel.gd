class_name ElementTypePanel
extends Control

## 元素类型选择面板（源头/收集器共享）
## - Mode.SOURCE: 选择源头的产出元素类型
## - Mode.COLLECTOR: 选择收集器的筛选元素类型（额外提供"全部"按钮清空筛选）

enum Mode { SOURCE, COLLECTOR }

var target: Node = null
var mode: int = Mode.SOURCE

const OFFSET_Y: float = -20.0

## 存储动态创建的按钮: {element_id: Button}
var _buttons: Dictionary = {}

@onready var _vbox: VBoxContainer = $Panel/VBoxContainer

func _ready() -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	EventBus.element_type_panel_opened.emit()
	_create_buttons()
	_update_selection_highlight()

func _exit_tree() -> void:
	EventBus.element_type_panel_closed.emit()

## 根据 ElementRegistry 动态创建按钮
## COLLECTOR 模式额外提供"全部"按钮（element_id="" 表示清空筛选）
func _create_buttons() -> void:
	# 仅清除已有的 Button 子节点（保留 TitleLabel、HSeparator 等非按钮节点）
	for child: Node in _vbox.get_children():
		if child is Button:
			child.queue_free()
	_buttons.clear()

	# COLLECTOR 模式额外提供"全部"按钮
	if mode == Mode.COLLECTOR:
		_add_button("全部", "")

	var all_types: Dictionary = ElementRegistry.get_all_element_types()
	for element_id: String in all_types:
		var type_data: ElementTypeData = all_types[element_id]
		_add_button(type_data.display_name, element_id)

func _add_button(label_text: String, element_id: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 32)

	# 使用元素颜色作为按钮背景提示；"全部"按钮用白色
	var type_data: ElementTypeData = ElementRegistry.get_element_type(element_id)
	var style := StyleBoxFlat.new()
	if type_data:
		style.bg_color = type_data.color
	else:
		style.bg_color = Color.WHITE
	style.bg_color.a = 0.3
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(_on_type_selected.bind(element_id))
	_vbox.add_child(btn)
	_buttons[element_id] = btn

func _on_type_selected(type_id: String) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	# 读取节点 grid_position（BuildingBase 成员），用于通知 SaveManager 触发保存
	var grid_pos: Vector2i = (target as BuildingBase).grid_position
	match mode:
		Mode.SOURCE:
			(target as SourceNode).set_element_type(type_id)
		Mode.COLLECTOR:
			(target as CollectorNode).set_filter(type_id)
	# 通知 SaveManager 触发延迟保存（复用现有 debounce 机制）
	EventBus.element_type_changed.emit(grid_pos)
	queue_free()

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	_update_position()

func _update_position() -> void:
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		return

	var world_pos: Vector2 = (target as Node2D).global_position
	var screen_pos: Vector2 = camera.get_canvas_transform() * world_pos

	var panel_size: Vector2 = size
	var pos_x: float = screen_pos.x - panel_size.x / 2.0
	var pos_y: float = screen_pos.y - panel_size.y + OFFSET_Y

	pos_x = clampf(pos_x, 0, viewport.size.x - panel_size.x)
	pos_y = clampf(pos_y, 0, viewport.size.y - panel_size.y)

	global_position = Vector2(pos_x, pos_y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = (event as InputEventMouseButton).position
		if not Rect2(Vector2.ZERO, size).has_point(pos):
			queue_free()
			accept_event()

## 高亮当前选中的元素按钮
func _update_selection_highlight() -> void:
	var selected: String = ""
	match mode:
		Mode.SOURCE:
			var source := target as SourceNode
			# 未确认类型（关闭态）不高亮任何按钮，与灰显外观保持一致
			selected = source.element_type_id if source.has_type_selected() else ""
		Mode.COLLECTOR:
			selected = (target as CollectorNode).filter_element_type
	for type_id: String in _buttons.keys():
		var btn: Button = _buttons[type_id]
		var is_selected: bool = type_id == selected
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			style.border_width_left = 2 if is_selected else 0
			style.border_width_right = 2 if is_selected else 0
			style.border_width_top = 2 if is_selected else 0
			style.border_width_bottom = 2 if is_selected else 0
			style.border_color = Color(1, 1, 1, 0.9) if is_selected else Color.TRANSPARENT
