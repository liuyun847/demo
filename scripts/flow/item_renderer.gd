class_name ItemRenderer
extends Node2D

## 物品渲染器：消费 sim_tick_completed 事件，为每格维护一个视觉实体
## （数字=圆形，操作=方形；色块 + 数值/操作名 Label），并做位置插值平滑。
## 面槽物品（0 格贴脸直传，事件带 "face" 偏移）定位到共享边中点：
## 视觉键 = Vector3i(cell.x, cell.y, face 方向索引)，与网格格视觉键（Vector2i）分离。

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

var _grid: ItemGrid = null
var _visuals: Dictionary = {}     # Vector2i -> Visual（网格格物品）
var _face_visuals: Dictionary = {} # Vector3i(cell.x, cell.y, face 索引) -> Visual（面槽物品）
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
	for v: Visual in _visuals.values():
		_advance(v, step)
	for v: Visual in _face_visuals.values():
		_advance(v, step)

func _advance(v: Visual, step: float) -> void:
	if not v.moving:
		return
	v.t += step
	if v.t >= 1.0:
		v.t = 1.0
		v.moving = false
	v.node.position = v.from.lerp(v.to, v.t)

func _on_sim_tick(events: Array) -> void:
	if _grid == null:
		return
	# 本 tick 涉及到的视觉键集合：未涉及的视觉吸附回逻辑位置
	var touched: Dictionary = {}
	for e: Dictionary in events:
		_process_event(e, touched)
	for key: Variant in _visuals.keys():
		if touched.has(key):
			continue
		var v: Visual = _visuals[key]
		if v.moving:
			v.moving = false
		v.node.position = _cell_world(key)
	for key: Variant in _face_visuals.keys():
		if touched.has(key):
			continue
		var v: Visual = _face_visuals[key]
		if v.moving:
			v.moving = false
		v.node.position = _face_world(key)

func _process_event(e: Dictionary, touched: Dictionary) -> void:
	match e.get("kind", ""):
		"spawn":
			var at: Vector2i = e.at
			var face: Vector2i = e.get("face", Vector2i.ZERO)
			var key: Variant = _visual_key(at, face)
			_ensure_visual(key, e.item, _pos_world(at, face))
			touched[key] = true
		"despawn":
			var at_d: Vector2i = e.at
			var face_d: Vector2i = e.get("face", Vector2i.ZERO)
			var key_d: Variant = _visual_key(at_d, face_d)
			_remove_visual(key_d)
			touched[key_d] = true
		"move":
			var from: Vector2i = e.from
			var to: Vector2i = e.to
			var from_face: Vector2i = e.get("from_face", Vector2i.ZERO)
			var to_face: Vector2i = e.get("to_face", Vector2i.ZERO)
			var from_key: Variant = _visual_key(from, from_face)
			var to_key: Variant = _visual_key(to, to_face)
			var v: Visual = _get_or_create_visual(from_key, e.item, _pos_world(from, from_face))
			_erase_visual(from_key)
			_set_visual(to_key, v)
			v.from = _pos_world(from, from_face)
			v.to = _pos_world(to, to_face)
			v.t = 0.0
			v.moving = true
			v.node.position = v.from
			touched[from_key] = true
			touched[to_key] = true

# ---------- 视觉键 / 位置 ----------

func _cell_world(cell: Vector2i) -> Vector2:
	return GridCoordinate.grid_to_world(cell)

## 视觉键：面偏移非零 → Vector3i(cell.x, cell.y, face 索引)；否则网格格键 Vector2i
func _visual_key(cell: Vector2i, face: Vector2i) -> Variant:
	if face == Vector2i.ZERO:
		return cell
	return Vector3i(cell.x, cell.y, _face_index(face))

func _face_index(face: Vector2i) -> int:
	match face:
		Vector2i(1, 0):
			return 0
		Vector2i(0, 1):
			return 1
		Vector2i(-1, 0):
			return 2
		Vector2i(0, -1):
			return 3
		_:
			# 面偏移只应由模拟器写入（四方向之一），未知值兜底为北向避免越界
			return 3

func _pos_world(cell: Vector2i, face: Vector2i) -> Vector2:
	var base := _cell_world(cell)
	if face == Vector2i.ZERO:
		return base
	return base + Vector2(face.x, face.y) * (GameConfig.CELL_SIZE / 2.0)

func _face_world(key: Vector3i) -> Vector2:
	var cell := Vector2i(key.x, key.y)
	var face: Vector2i = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)][key.z]
	return _pos_world(cell, face)

# ---------- 视觉存取（网格格/面槽两套字典） ----------

func _get_visual(key: Variant) -> Visual:
	if key is Vector3i:
		return _face_visuals.get(key) as Visual
	return _visuals.get(key) as Visual

func _set_visual(key: Variant, v: Visual) -> void:
	if key is Vector3i:
		_face_visuals[key] = v
	else:
		_visuals[key] = v

func _erase_visual(key: Variant) -> void:
	if key is Vector3i:
		_face_visuals.erase(key)
	else:
		_visuals.erase(key)

func _get_or_create_visual(key: Variant, item: Item, pos: Vector2) -> Visual:
	var v: Visual = _get_visual(key)
	if v == null:
		v = _create_visual(pos, item)
		_set_visual(key, v)
	return v

func _ensure_visual(key: Variant, item: Item, pos: Vector2) -> void:
	var v: Visual = _get_visual(key)
	if v == null:
		v = _create_visual(pos, item)
		_set_visual(key, v)
		return
	_refresh_label(v, item)

func _create_visual(pos: Vector2, item: Item) -> Visual:
	var v := Visual.new()
	var node := Node2D.new()
	node.position = pos
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
	return v

func _refresh_label(v: Visual, item: Item) -> void:
	if v.label != null:
		v.label.text = item.to_display_text()

func _remove_visual(key: Variant) -> void:
	var v: Visual = _get_visual(key)
	if v == null:
		return
	v.node.queue_free()
	_erase_visual(key)

func clear_all() -> void:
	for v: Visual in _visuals.values():
		if v.node != null and is_instance_valid(v.node):
			v.node.queue_free()
	for v: Visual in _face_visuals.values():
		if v.node != null and is_instance_valid(v.node):
			v.node.queue_free()
	_visuals.clear()
	_face_visuals.clear()
