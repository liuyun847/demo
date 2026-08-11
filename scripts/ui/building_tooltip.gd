class_name BuildingTooltip
extends Control

const GAP: float = 8.0
## 摘要文本最大内容宽度：超出自动换行，防止长文本溢出卡片
const MAX_CONTENT_WIDTH: float = 200.0

var _target_node: Node2D = null
var _hovered_grid_pos: Vector2i = Vector2i.MIN
var _panel_open: bool = false

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var _summary_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/SummaryContainer
@onready var _margin: MarginContainer = $Panel/MarginContainer

var _panel_style: StyleBoxFlat = null

func _on_building_removed(grid_pos: Vector2i) -> void:
	if _target_node == null:
		return
	if grid_pos != _hovered_grid_pos:
		return
	_hovered_grid_pos = Vector2i.MIN
	_target_node = null
	hide()

func _ready() -> void:
	hide()
	_create_styles()
	_apply_styles()
	EventBus.building_hovered.connect(_on_building_hovered)
	EventBus.building_hover_exited.connect(_on_building_hover_exited)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.camera_changed.connect(_update_position)
	EventBus.element_type_panel_opened.connect(_on_element_panel_opened)
	EventBus.element_type_panel_closed.connect(_on_element_panel_closed)

func _exit_tree() -> void:
	if EventBus.building_hovered.is_connected(_on_building_hovered):
		EventBus.building_hovered.disconnect(_on_building_hovered)
	if EventBus.building_hover_exited.is_connected(_on_building_hover_exited):
		EventBus.building_hover_exited.disconnect(_on_building_hover_exited)
	if EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.disconnect(_on_building_removed)
	if EventBus.camera_changed.is_connected(_update_position):
		EventBus.camera_changed.disconnect(_update_position)
	if EventBus.element_type_panel_opened.is_connected(_on_element_panel_opened):
		EventBus.element_type_panel_opened.disconnect(_on_element_panel_opened)
	if EventBus.element_type_panel_closed.is_connected(_on_element_panel_closed):
		EventBus.element_type_panel_closed.disconnect(_on_element_panel_closed)

func _create_styles() -> void:
	_panel_style = StyleBoxFlat.new()
	_panel_style.draw_center = true
	_panel_style.bg_color = Color(0.98, 0.98, 0.98, 0.95)
	_panel_style.border_color = Color(0.7, 0.7, 0.7, 1.0)
	_panel_style.border_width_left = 1
	_panel_style.border_width_right = 1
	_panel_style.border_width_top = 1
	_panel_style.border_width_bottom = 1
	_panel_style.corner_radius_top_left = 6
	_panel_style.corner_radius_top_right = 6
	_panel_style.corner_radius_bottom_left = 6
	_panel_style.corner_radius_bottom_right = 6
	_panel_style.set_content_margin_all(8)

func _apply_styles() -> void:
	_panel.set(&"theme_override_styles/panel", _panel_style)
	_panel.queue_redraw()

func _on_element_panel_opened() -> void:
	_panel_open = true
	hide()

func _on_element_panel_closed() -> void:
	_panel_open = false

func _on_building_hovered(grid_pos: Vector2i, node: Node2D) -> void:
	if _panel_open:
		return
	_hovered_grid_pos = grid_pos
	_target_node = node
	_update_content()
	show()
	await _recalculate_size()
	_update_position()

func _on_building_hover_exited(_grid_pos: Vector2i) -> void:
	_hovered_grid_pos = Vector2i.MIN
	_target_node = null
	hide()

func _update_content() -> void:
	if _target_node == null:
		return

	var building_name: String = "未知建筑"
	var summary: Dictionary = {}

	if _target_node is BuildingBase:
		building_name = _target_node.get_building_name()
		summary = _target_node.get_tooltip_summary()

	_name_label.text = building_name

	# 立即从容器移除旧摘要 Label（仅延迟释放对象）。
	# queue_free 延迟到帧末才真正删除，而 _recalculate_size 的 await process_frame
	# 在帧末 flush_delete_queue 之前恢复，旧 Label 会残留进最小尺寸计算导致卡片高度虚高。
	for child: Node in _summary_container.get_children():
		_summary_container.remove_child(child)
		child.queue_free()

	if summary.is_empty():
		_summary_container.add_child(_create_summary_label("暂无属性", Color(0.25, 0.25, 0.25)))
	else:
		for key: String in summary.keys():
			_summary_container.add_child(_create_summary_label("%s: %s" % [key, summary[key]], Color(0.1, 0.1, 0.1)))

## 创建摘要 Label：短文本按自然宽度显示（卡片贴合内容），超过上限才限制宽度触发换行
func _create_summary_label(text: String, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", font_color)
	var font := label.get_theme_font("font")
	var text_width: float = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
	).x
	if text_width > MAX_CONTENT_WIDTH:
		label.custom_minimum_size = Vector2(MAX_CONTENT_WIDTH, 0)
	return label

func _recalculate_size() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	var content_min: Vector2 = vbox.get_combined_minimum_size()
	var margin_w: float = _margin.get_theme_constant("margin_left") + _margin.get_theme_constant("margin_right")
	var margin_h: float = _margin.get_theme_constant("margin_top") + _margin.get_theme_constant("margin_bottom")
	# 卡片尺寸完全贴合内容（含内边距），不再强制最小宽高导致大面积空白
	offset_right = offset_left + content_min.x + margin_w
	offset_bottom = offset_top + content_min.y + margin_h

func _update_position() -> void:
	if not visible:
		return
	if not is_instance_valid(_target_node) or not is_visible_in_tree():
		_target_node = null
		hide()
		return

	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		return

	var world_pos: Vector2 = _target_node.global_position
	var screen_pos: Vector2 = camera.get_canvas_transform() * world_pos

	var tooltip_size: Vector2 = size
	var canvas_scale_y: float = camera.get_canvas_transform().get_scale().y
	var cell_top_y: float = screen_pos.y - GameConfig.CELL_SIZE * 0.5 * canvas_scale_y
	var pos_x: float = screen_pos.x - tooltip_size.x / 2.0
	var pos_y: float = cell_top_y - tooltip_size.y - GAP

	pos_x = clampf(pos_x, 0, viewport.size.x - tooltip_size.x)
	pos_y = clampf(pos_y, 0, viewport.size.y - tooltip_size.y)

	global_position = Vector2(pos_x, pos_y)
