class_name BuildingTooltip
extends Control

const GAP: float = 8.0
## 摘要文本最大内容宽度：超出自动换行，防止长文本溢出卡片
const MAX_CONTENT_WIDTH: float = 200.0

var _target_node: Node2D = null
var _hovered_grid_pos: Vector2i = Vector2i.MIN
var _panel_open: bool = false
## 尺寸重算代次：每次 hover 递增；_recalculate_size 续体恢复时代次过期则作废，
## 防止快速切换悬停建筑时旧续体用过期内容覆盖新布局（交错恢复导致文字与面板错位）
var _resize_generation: int = 0

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
	# 隐藏即作废 in-flight 尺寸重算（其续体恢复时不再定位）
	_resize_generation += 1
	hide()

func _ready() -> void:
	hide()
	_create_styles()
	_apply_styles()
	EventBus.building_hovered.connect(_on_building_hovered)
	EventBus.building_hover_exited.connect(_on_building_hover_exited)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.camera_changed.connect(_update_position)
	EventBus.config_panel_opened.connect(_on_config_panel_opened)
	EventBus.config_panel_closed.connect(_on_config_panel_closed)

func _exit_tree() -> void:
	if EventBus.building_hovered.is_connected(_on_building_hovered):
		EventBus.building_hovered.disconnect(_on_building_hovered)
	if EventBus.building_hover_exited.is_connected(_on_building_hover_exited):
		EventBus.building_hover_exited.disconnect(_on_building_hover_exited)
	if EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.disconnect(_on_building_removed)
	if EventBus.camera_changed.is_connected(_update_position):
		EventBus.camera_changed.disconnect(_update_position)
	if EventBus.config_panel_opened.is_connected(_on_config_panel_opened):
		EventBus.config_panel_opened.disconnect(_on_config_panel_opened)
	if EventBus.config_panel_closed.is_connected(_on_config_panel_closed):
		EventBus.config_panel_closed.disconnect(_on_config_panel_closed)

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

func _on_config_panel_opened() -> void:
	_panel_open = true
	hide()

func _on_config_panel_closed() -> void:
	_panel_open = false

func _on_building_hovered(grid_pos: Vector2i, node: Node2D) -> void:
	if _panel_open:
		return
	_hovered_grid_pos = grid_pos
	_target_node = node
	_update_content()
	show()
	_resize_generation += 1
	var generation := _resize_generation
	if await _recalculate_size(generation):
		_update_position()

func _on_building_hover_exited(_grid_pos: Vector2i) -> void:
	_hovered_grid_pos = Vector2i.MIN
	_target_node = null
	# 隐藏即作废 in-flight 尺寸重算（其续体恢复时不再定位）
	_resize_generation += 1
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
			# 名称已由标题（NameLabel）显示，摘要中跳过冗余的 name 键
			if key == "name":
				continue
			_summary_container.add_child(_create_summary_label("%s: %s" % [key, summary[key]], Color(0.1, 0.1, 0.1)))

## 创建摘要 Label：短文本按自然宽度单行显示（卡片贴合内容）；超过上限才限制宽度触发换行。
## 注意：autowrap 模式下 Label 的 get_minimum_size().x 恒为 1（可压缩到任意窄），
## 若短文本也开 autowrap，VBox 会塌缩到标题宽度、把摘要挤成竖排窄条（曾致卡片错位），
## 故短文本不开启 autowrap，此时 min size 宽度 = 文本自然宽度。
func _create_summary_label(text: String, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", font_color)
	var font := label.get_theme_font("font")
	var text_width: float = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
	).x
	if text_width > MAX_CONTENT_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(MAX_CONTENT_WIDTH, 0)
	return label

## 重算卡片尺寸（返回 false 表示本次测量作废：代次过期或已不在场景树）。
## 注意 autowrap Label 的 min size 宽度恒为 1，测量必须在内容布局稳定后取
## get_combined_minimum_size()，且旧续体恢复时代次过期必须作废，否则旧内容覆盖新布局。
func _recalculate_size(generation: int) -> bool:
	await get_tree().process_frame
	if generation != _resize_generation:
		# 内容已被更新的悬停重建，本次测量作废（避免旧尺寸覆盖新内容）
		return false
	if not is_inside_tree():
		return false
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	var content_min: Vector2 = vbox.get_combined_minimum_size()
	var margin_w: float = _margin.get_theme_constant("margin_left") + _margin.get_theme_constant("margin_right")
	var margin_h: float = _margin.get_theme_constant("margin_top") + _margin.get_theme_constant("margin_bottom")
	# 卡片尺寸完全贴合内容（含内边距），不再强制最小宽高导致大面积空白
	offset_right = offset_left + content_min.x + margin_w
	offset_bottom = offset_top + content_min.y + margin_h
	return true

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
