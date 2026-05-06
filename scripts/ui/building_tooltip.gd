class_name BuildingTooltip
extends Control

const OFFSET_Y: float = -12.0
const MIN_WIDTH: float = 140.0

var _target_node: Node2D = null
var _is_expanded: bool = false

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var _summary_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/SummaryContainer
@onready var _expand_button: Button = $Panel/MarginContainer/VBoxContainer/ExpandButton
@onready var _details_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/DetailsContainer
@onready var _margin: MarginContainer = $Panel/MarginContainer

var _panel_style: StyleBoxFlat = null

func _ready() -> void:
	hide()
	_create_styles()
	_apply_styles()
	_expand_button.pressed.connect(_on_expand_pressed)
	EventBus.building_hovered.connect(_on_building_hovered)
	EventBus.building_hover_exited.connect(_on_building_hover_exited)

func _exit_tree() -> void:
	EventBus.building_hovered.disconnect(_on_building_hovered)
	EventBus.building_hover_exited.disconnect(_on_building_hover_exited)

func _create_styles() -> void:
	_panel_style = StyleBoxFlat.new()
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
	_panel.add_theme_stylebox_override("panel", _panel_style)

func _on_building_hovered(_grid_pos: Vector2i, node: Node2D) -> void:
	_target_node = node
	_is_expanded = false
	_expand_button.text = "展开详情 ▼"
	_details_container.hide()
	_update_content()
	show()

func _on_building_hover_exited(_grid_pos: Vector2i) -> void:
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

func _update_content() -> void:
	if _target_node == null:
		return

	var building_name := "未知建筑"
	var summary: Dictionary = {}

	if _target_node.has_method("get_building_name"):
		building_name = _target_node.get_building_name()
	else:
		building_name = _get_fallback_name(_target_node)

	if _target_node.has_method("get_tooltip_summary"):
		summary = _target_node.get_tooltip_summary()

	_name_label.text = building_name

	for child in _summary_container.get_children():
		child.queue_free()

	if summary.is_empty():
		var label := Label.new()
		label.text = "暂无属性"
		label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
		_summary_container.add_child(label)
	else:
		for key in summary.keys():
			var label := Label.new()
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
	if _target_node.has_method("get_tooltip_details"):
		details = _target_node.get_tooltip_details()

	for child in _details_container.get_children():
		child.queue_free()

	if details.is_empty():
		var label := Label.new()
		label.text = "暂无详细信息"
		label.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
		_details_container.add_child(label)
	else:
		for key in details.keys():
			var label := Label.new()
			label.text = "%s: %s" % [key, details[key]]
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			_details_container.add_child(label)

func _get_fallback_name(node: Node) -> String:
	if node.name.begins_with("Building_"):
		var parts := node.name.split("_")
		if parts.size() >= 3:
			return "建筑"
	return "建筑"

func _process(_delta: float) -> void:
	if _target_node == null or not is_visible_in_tree():
		return

	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if not camera:
		return

	var world_pos: Vector2 = _target_node.global_position
	var screen_pos: Vector2 = camera.get_canvas_transform() * world_pos

	var tooltip_size := size
	var pos_x := screen_pos.x - tooltip_size.x / 2.0
	var pos_y := screen_pos.y - tooltip_size.y + OFFSET_Y

	pos_x = clampf(pos_x, 0, viewport.size.x - tooltip_size.x)
	pos_y = clampf(pos_y, 0, viewport.size.y - tooltip_size.y)

	global_position = Vector2(pos_x, pos_y)
