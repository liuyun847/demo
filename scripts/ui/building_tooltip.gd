class_name BuildingTooltip
extends Control

const OFFSET_Y: float = -12.0
const MIN_WIDTH: float = 140.0
const MIN_HEIGHT: float = 60.0

var _target_node: Node2D = null
var _is_expanded: bool = false
var _hovered_grid_pos: Vector2i = Vector2i.MIN

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var _summary_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/SummaryContainer
@onready var _expand_button: Button = $Panel/MarginContainer/VBoxContainer/ExpandButton
@onready var _details_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/DetailsContainer
@onready var _margin: MarginContainer = $Panel/MarginContainer

var _panel_style: StyleBoxFlat = null

func _on_building_removed(grid_pos: Vector2i) -> void:
	if _target_node == null:
		return
	if grid_pos != _hovered_grid_pos:
		return
	_hovered_grid_pos = Vector2i.MIN
	_target_node = null
	_is_expanded = false
	hide()

func _ready() -> void:
	hide()
	_create_styles()
	_apply_styles()
	_expand_button.pressed.connect(_on_expand_pressed)
	EventBus.building_hovered.connect(_on_building_hovered)
	EventBus.building_hover_exited.connect(_on_building_hover_exited)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.camera_changed.connect(_update_position)

func _exit_tree() -> void:
	if EventBus.building_hovered.is_connected(_on_building_hovered):
		EventBus.building_hovered.disconnect(_on_building_hovered)
	if EventBus.building_hover_exited.is_connected(_on_building_hover_exited):
		EventBus.building_hover_exited.disconnect(_on_building_hover_exited)
	if EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.disconnect(_on_building_removed)
	if EventBus.camera_changed.is_connected(_update_position):
		EventBus.camera_changed.disconnect(_update_position)

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

func _on_building_hovered(grid_pos: Vector2i, node: Node2D) -> void:
	_hovered_grid_pos = grid_pos
	_target_node = node
	_is_expanded = false
	_expand_button.text = "展开详情 ▼"
	_details_container.hide()
	_update_content()
	show()
	_update_position.call_deferred()

func _on_building_hover_exited(_grid_pos: Vector2i) -> void:
	_hovered_grid_pos = Vector2i.MIN
	_target_node = null
	hide()

func _on_expand_pressed() -> void:
	_is_expanded = not _is_expanded
	if _is_expanded:
		_expand_button.text = "收起详情 ▲"
		_update_details()
		_details_container.show()
	else:
		_expand_button.text = "展开详情 ▼"
		_details_container.hide()
	_recalculate_size()
	_update_position.call_deferred()

func _update_content() -> void:
	if _target_node == null:
		return

	var building_name: String = "未知建筑"
	var summary: Dictionary = {}

	if _target_node is FluidNodeBase:
		building_name = _target_node.get_building_name()
		summary = _target_node.get_tooltip_summary()
	else:
		building_name = _get_fallback_name(_target_node)

	_name_label.text = building_name

	for child in _summary_container.get_children():
		child.queue_free()

	if summary.is_empty():
		var label: Label = Label.new()
		label.text = "暂无属性"
		label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
		_summary_container.add_child(label)
	else:
		for key in summary.keys():
			var label: Label = Label.new()
			label.text = "%s: %s" % [key, summary[key]]
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			_summary_container.add_child(label)

	if _is_expanded:
		_update_details()

func _update_details() -> void:
	if _target_node == null:
		return

	var details: Dictionary = {}
	if _target_node is FluidNodeBase:
		details = _target_node.get_tooltip_details()

	for child in _details_container.get_children():
		child.queue_free()

	if details.is_empty():
		var label: Label = Label.new()
		label.text = "暂无详细信息"
		label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
		_details_container.add_child(label)
	else:
		for key in details.keys():
			var label: Label = Label.new()
			label.text = "%s: %s" % [key, details[key]]
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			_details_container.add_child(label)

func _get_fallback_name(node: Node) -> String:
	if node.has_meta("building_type"):
		var bt: String = node.get_meta("building_type")
		if bt.begins_with("type_"):
			var idx: int = bt.substr(5).to_int()
			return "占位-%d" % idx
	return "建筑"

func _recalculate_size() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer
	var content_min: Vector2 = vbox.get_combined_minimum_size()
	var margin_w: float = _margin.get_theme_constant("margin_left") + _margin.get_theme_constant("margin_right")
	var margin_h: float = _margin.get_theme_constant("margin_top") + _margin.get_theme_constant("margin_bottom")
	var new_w: float = maxf(content_min.x + margin_w, MIN_WIDTH)
	var new_h: float = maxf(content_min.y + margin_h, MIN_HEIGHT)
	offset_right = offset_left + new_w
	offset_bottom = offset_top + new_h

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
	var pos_x: float = screen_pos.x - tooltip_size.x / 2.0
	var pos_y: float = screen_pos.y - tooltip_size.y + OFFSET_Y

	pos_x = clampf(pos_x, 0, viewport.size.x - tooltip_size.x)
	pos_y = clampf(pos_y, 0, viewport.size.y - tooltip_size.y)

	global_position = Vector2(pos_x, pos_y)
