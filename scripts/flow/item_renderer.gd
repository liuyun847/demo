class_name ItemRenderer
extends Node2D

## 物品渲染器：消费 sim_tick_completed 事件，为每格维护一个视觉实体
## （数字=圆形，操作=方形；色块 + 数值/操作名 Label），并做位置插值平滑。

const NUM_COLOR: Color = Color("#4fc3f7")
const OP_COLOR: Color = Color("#ffb74d")
const ITEM_RADIUS: float = 14.0
const LABEL_FONT_SIZE: int = 13

## 视觉实体：节点 + 插值状态
class Visual:
	extends RefCounted

	var node: Node2D = null
	var label: Label = null
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var t: float = 0.0
	var moving: bool = false
	var cell: Vector2i = Vector2i.ZERO

var _grid: ItemGrid = null
var _visuals: Dictionary = {}  # Vector2i -> Visual
var _tick_duration: float = GameConfig.SIMULATION_TICK_INTERVAL

func setup(grid: ItemGrid, tick_duration: float = -1.0) -> void:
	_grid = grid
	if tick_duration > 0.0:
		_tick_duration = tick_duration

func _ready() -> void:
	EventBus.sim_tick_completed.connect(_on_sim_tick)

func _exit_tree() -> void:
	if EventBus.sim_tick_completed.is_connected(_on_sim_tick):
		EventBus.sim_tick_completed.disconnect(_on_sim_tick)

## 每帧推进插值
func _process(delta: float) -> void:
	if _tick_duration <= 0.0:
		return
	var step: float = delta / _tick_duration
	for key: Vector2i in _visuals.keys():
		var v: Visual = _visuals[key]
		if not v.moving:
			continue
		v.t += step
		if v.t >= 1.0:
			v.t = 1.0
			v.moving = false
		v.node.position = v.from.lerp(v.to, v.t)

func _on_sim_tick(events: Array) -> void:
	if _grid == null:
		return
	# 本 tick 涉及到的位置集合：未涉及的视觉吸附回逻辑格
	var touched: Dictionary[Vector2i, bool] = {}
	for e: Dictionary in events:
		_process_event(e, touched)
	for cell: Vector2i in _visuals.keys():
		if touched.has(cell):
			continue
		var v: Visual = _visuals[cell]
		if v.moving:
			v.moving = false
		v.node.position = _cell_world(cell)

func _process_event(e: Dictionary, touched: Dictionary[Vector2i, bool]) -> void:
	match e.get("kind", ""):
		"spawn":
			var at: Vector2i = e.at
			_ensure_visual(at, e.item)
			touched[at] = true
		"despawn":
			var at_d: Vector2i = e.at
			_remove_visual(at_d)
			touched[at_d] = true
		"move":
			var from: Vector2i = e.from
			var to: Vector2i = e.to
			var v: Visual = _get_or_create_visual(from, e.item)
			_visuals.erase(from)
			_visuals[to] = v
			v.cell = to
			v.from = _cell_world(from)
			v.to = _cell_world(to)
			v.t = 0.0
			v.moving = true
			v.node.position = v.from
			touched[from] = true
			touched[to] = true

func _cell_world(cell: Vector2i) -> Vector2:
	return GridCoordinate.grid_to_world(cell)

func _get_or_create_visual(cell: Vector2i, item: Item) -> Visual:
	var v: Visual = _visuals.get(cell) as Visual
	if v == null:
		v = _create_visual(cell, item)
	return v

func _ensure_visual(cell: Vector2i, item: Item) -> void:
	if not _visuals.has(cell):
		_create_visual(cell, item)
		return
	_refresh_label(_visuals[cell], item)

func _create_visual(cell: Vector2i, item: Item) -> Visual:
	var v := Visual.new()
	v.cell = cell
	var node := Node2D.new()
	node.position = _cell_world(cell)
	node.z_index = 5
	v.node = node
	# 色块：数字=圆，操作=方
	var shape := ItemShape.new()
	shape.is_op = item.is_op()
	shape.color = OP_COLOR if item.is_op() else NUM_COLOR
	shape.radius = ITEM_RADIUS
	node.add_child(shape)
	# 数值/操作名 Label
	var label := Label.new()
	label.text = item.to_display_text()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(ITEM_RADIUS * 2.6, ITEM_RADIUS * 1.4)
	label.position = Vector2(-ITEM_RADIUS * 1.3, -ITEM_RADIUS * 0.7)
	var ls := LabelSettings.new()
	ls.font_size = LABEL_FONT_SIZE
	ls.font_color = Color.WHITE
	ls.outline_size = 2
	ls.outline_color = Color.BLACK
	label.label_settings = ls
	node.add_child(label)
	v.label = label
	add_child(node)
	_visuals[cell] = v
	return v

func _refresh_label(v: Visual, item: Item) -> void:
	if v.label != null:
		v.label.text = item.to_display_text()

func _remove_visual(cell: Vector2i) -> void:
	var v: Visual = _visuals.get(cell) as Visual
	if v == null:
		return
	v.node.queue_free()
	_visuals.erase(cell)

func clear_all() -> void:
	for v: Visual in _visuals.values():
		if v.node != null and is_instance_valid(v.node):
			v.node.queue_free()
	_visuals.clear()