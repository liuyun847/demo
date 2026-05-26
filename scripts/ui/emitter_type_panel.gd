class_name EmitterTypePanel
extends Control

var target_emitter: EmitterNode = null

const OFFSET_Y: float = -20.0

@onready var _water_btn: Button = $Panel/VBoxContainer/WaterButton

func _ready() -> void:
	if not is_instance_valid(target_emitter):
		queue_free()
		return

	EventBus.emitter_type_panel_opened.emit()
	_update_selection_highlight()

	_water_btn.pressed.connect(_on_type_selected.bind("water"))

func _exit_tree() -> void:
	EventBus.emitter_type_panel_closed.emit()

func _on_type_selected(type_id: String) -> void:
	if not is_instance_valid(target_emitter):
		queue_free()
		return

	target_emitter.set_element_type(type_id)
	queue_free()

func _process(_delta: float) -> void:
	if not is_instance_valid(target_emitter):
		queue_free()
		return
	_update_position()

func _update_position() -> void:
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		return

	var world_pos: Vector2 = target_emitter.global_position
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

func _update_selection_highlight() -> void:
	var selected: String = target_emitter.element_type_id
	var buttons := {"water": _water_btn}
	for type_id: String in buttons.keys():
		var btn: Button = buttons[type_id]
		var is_selected: bool = type_id == selected
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			style.border_width_left = 2 if is_selected else 0
			style.border_width_right = 2 if is_selected else 0
			style.border_width_top = 2 if is_selected else 0
			style.border_width_bottom = 2 if is_selected else 0
			style.border_color = Color(1, 1, 1, 0.9) if is_selected else Color.TRANSPARENT