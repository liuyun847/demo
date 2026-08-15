class_name ElementRenderer
extends Node2D

## 方向 C：MultiMesh 实例批处理渲染，替代逐格 draw_rect。
## 元素海量时（数千格水体），原 _draw 每次变化都全量重绘全部格子（每格 2 次 draw_rect），
## 是渲染侧最大瓶颈；改为 GPU 实例化后，单格增删改只需更新 1 个实例的变换/颜色。

## 元素视觉字典: {Vector2i: ElementTypeData}（保留原语义，供颜色查询）
var _element_visuals: Dictionary = {}

## MultiMesh 实例索引映射: {Vector2i: int}
var _instance_index: Dictionary = {}
## 实例索引 → 格子坐标（移除时 swap-last 回填用）
var _pos_by_index: Dictionary = {}

## 边框层：环形网格（外圈比填充层大 BORDER_WIDTH*2、内孔与填充层同大），画在填充层之下，
## 呈现原 draw_rect 的不透明描边；内部镂空，由半透明填充层呈现（保持 ELEMENT_ALPHA 半透明效果）
var _border_layer: MultiMeshInstance2D = null
## 填充层：半透明元素色
var _fill_layer: MultiMeshInstance2D = null

## 原 draw_rect 描边宽度（像素）
const _BORDER_WIDTH: float = 2.0
## 初始实例容量
const _INITIAL_CAPACITY: int = 64

func _ready() -> void:
	_setup_meshes()
	EventBus.element_spawned.connect(_on_element_spawned)
	EventBus.element_removed.connect(_on_element_removed)
	EventBus.element_moved.connect(_on_element_moved)

func _exit_tree() -> void:
	if EventBus.element_spawned.is_connected(_on_element_spawned):
		EventBus.element_spawned.disconnect(_on_element_spawned)
	if EventBus.element_removed.is_connected(_on_element_removed):
		EventBus.element_removed.disconnect(_on_element_removed)
	if EventBus.element_moved.is_connected(_on_element_moved):
		EventBus.element_moved.disconnect(_on_element_moved)

## 初始化两个 MultiMesh 层（边框层在前=画在下层，填充层在后=画在上层）
func _setup_meshes() -> void:
	var element_size := float(GameConfig.BUILDING_SIZE) * 0.8
	_border_layer = MultiMeshInstance2D.new()
	_border_layer.name = "BorderLayer"
	# 边框用环形网格：内孔与填充层同大，内部镂空后仅边缘不透明（见 _create_ring_mesh）
	_border_layer.multimesh = _create_border_multimesh(
		element_size + _BORDER_WIDTH * 2.0, element_size)
	add_child(_border_layer)
	_fill_layer = MultiMeshInstance2D.new()
	_fill_layer.name = "FillLayer"
	_fill_layer.multimesh = _create_multimesh(element_size)
	add_child(_fill_layer)
	# 预分配容量，避免频繁增删实例时反复重分配 GPU 缓冲
	_border_layer.multimesh.instance_count = _INITIAL_CAPACITY
	_fill_layer.multimesh.instance_count = _INITIAL_CAPACITY
	# 初始可见数为 0（避免默认 -1=渲染全部实例时访问未写入槽位，属于防御性初始化）
	_set_visible_count(0)

## 创建指定尺寸的 QuadMesh MultiMesh（TRANSFORM_2D + 实例颜色）
func _create_multimesh(size: float) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	return _wrap_multimesh(quad)

## 创建环形边框 MultiMesh：外圈 outer_size、内孔 inner_size（用于不透明描边，内部镂空）
func _create_border_multimesh(outer_size: float, inner_size: float) -> MultiMesh:
	return _wrap_multimesh(_create_ring_mesh(outer_size, inner_size))

## 包装任意 Mesh 为 MultiMesh（TRANSFORM_2D + 实例颜色）
func _wrap_multimesh(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true  # 必须在 instance_count 为 0 时设置
	mm.mesh = mesh
	return mm

## 构建环形网格：四条边带（上/下/左/右）围成外方框，中心镂空。
## 边框层若用整块四边形会盖住下方的半透明填充层（混合后整体不透明），
## 环形网格让内部仅由填充层呈现，恢复原 draw_rect 的"半透明填充 + 不透明描边"效果。
func _create_ring_mesh(outer_size: float, inner_size: float) -> ArrayMesh:
	var outer := outer_size / 2.0
	var inner := inner_size / 2.0
	var verts := PackedVector2Array([
		# 上边带（y: -outer..-inner，x 全宽）
		Vector2(-outer, -outer), Vector2(outer, -outer), Vector2(outer, -inner), Vector2(-outer, -inner),
		# 下边带（y: inner..outer）
		Vector2(-outer, inner), Vector2(outer, inner), Vector2(outer, outer), Vector2(-outer, outer),
		# 左边带（x: -outer..-inner，y 在内孔范围）
		Vector2(-outer, -inner), Vector2(-inner, -inner), Vector2(-inner, inner), Vector2(-outer, inner),
		# 右边带（x: inner..outer）
		Vector2(inner, -inner), Vector2(outer, -inner), Vector2(outer, inner), Vector2(inner, inner),
	])
	var indices := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		4, 5, 6, 4, 6, 7,
		8, 9, 10, 8, 10, 11,
		12, 13, 14, 12, 14, 15,
	])
	var verts3d := PackedVector3Array()
	verts3d.resize(verts.size())
	for i in verts.size():
		var v: Vector2 = verts[i]
		verts3d[i] = Vector3(v.x, v.y, 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts3d
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## 格子坐标 → 实例中心世界坐标（与 GridCoordinate.grid_to_world 一致）
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * float(GameConfig.CELL_SIZE) + GameConfig.BUILDING_BORDER + GameConfig.BUILDING_SIZE / 2.0,
		grid_pos.y * float(GameConfig.CELL_SIZE) + GameConfig.BUILDING_BORDER + GameConfig.BUILDING_SIZE / 2.0
	)

## 确保两层容量足够（倍增扩容）
## 注意：Godot 4 的 MultiMesh.instance_count setter 会重建 GPU 缓冲并清空
## 全部实例数据（变换/颜色）。因此扩容后必须重新写入所有现有实例数据，
## 否则旧实例全部塌缩到原点 (0,0)，元素渲染错乱（堆叠/消失）。
func _ensure_capacity(needed: int) -> void:
	var capacity: int = _fill_layer.multimesh.instance_count
	if needed <= capacity:
		return
	var new_cap: int = max(capacity * 2, _INITIAL_CAPACITY)
	while new_cap < needed:
		new_cap *= 2
	_border_layer.multimesh.instance_count = new_cap
	_fill_layer.multimesh.instance_count = new_cap
	_restore_all_instances()

## 重新写入全部实例的变换/颜色（扩容清空缓冲后恢复；按索引映射遍历，扩容低频、均摊 O(1)）
func _restore_all_instances() -> void:
	for pos: Vector2i in _instance_index:
		var element_type: ElementTypeData = _element_visuals.get(pos)
		if element_type == null:
			continue
		var idx: int = _instance_index[pos]
		var instance_transform := Transform2D(0.0, _grid_to_world(pos))
		_border_layer.multimesh.set_instance_transform_2d(idx, instance_transform)
		_fill_layer.multimesh.set_instance_transform_2d(idx, instance_transform)
		var c: Color = element_type.color
		_border_layer.multimesh.set_instance_color(idx, Color(c.r, c.g, c.b, 1.0))
		_fill_layer.multimesh.set_instance_color(idx, Color(c.r, c.g, c.b, GameConfig.ELEMENT_ALPHA))

## 设置可见实例数（等于实际元素数）
func _set_visible_count(count: int) -> void:
	_border_layer.multimesh.visible_instance_count = count
	_fill_layer.multimesh.visible_instance_count = count

func clear_all() -> void:
	_element_visuals.clear()
	_instance_index.clear()
	_pos_by_index.clear()
	_set_visible_count(0)

func _on_element_spawned(grid_pos: Vector2i, element_type_id: String) -> void:
	var element_type: ElementTypeData = ElementRegistry.get_element_type(element_type_id)
	if element_type == null:
		return
	if _instance_index.has(grid_pos):
		return  # 防御：同一位置重复 spawn
	_element_visuals[grid_pos] = element_type
	var idx: int = _instance_index.size()
	_instance_index[grid_pos] = idx
	_pos_by_index[idx] = grid_pos
	_ensure_capacity(idx + 1)
	var instance_transform := Transform2D(0.0, _grid_to_world(grid_pos))
	_border_layer.multimesh.set_instance_transform_2d(idx, instance_transform)
	_fill_layer.multimesh.set_instance_transform_2d(idx, instance_transform)
	var c: Color = element_type.color
	_border_layer.multimesh.set_instance_color(idx, Color(c.r, c.g, c.b, 1.0))
	_fill_layer.multimesh.set_instance_color(idx, Color(c.r, c.g, c.b, GameConfig.ELEMENT_ALPHA))
	_set_visible_count(idx + 1)

func _on_element_removed(grid_pos: Vector2i, _element_type_id: String) -> void:
	_element_visuals.erase(grid_pos)
	if not _instance_index.has(grid_pos):
		return
	var idx: int = _instance_index[grid_pos]
	var last_idx: int = _instance_index.size() - 1
	if idx != last_idx:
		# swap-last 回填：把最后一个实例的数据搬到被移除的槽位，保持索引紧凑
		var last_pos: Vector2i = _pos_by_index[last_idx]
		_border_layer.multimesh.set_instance_transform_2d(
			idx, _border_layer.multimesh.get_instance_transform_2d(last_idx))
		_border_layer.multimesh.set_instance_color(
			idx, _border_layer.multimesh.get_instance_color(last_idx))
		_fill_layer.multimesh.set_instance_transform_2d(
			idx, _fill_layer.multimesh.get_instance_transform_2d(last_idx))
		_fill_layer.multimesh.set_instance_color(
			idx, _fill_layer.multimesh.get_instance_color(last_idx))
		_instance_index[last_pos] = idx
		_pos_by_index[idx] = last_pos
	_instance_index.erase(grid_pos)
	_pos_by_index.erase(last_idx)
	_set_visible_count(last_idx)

func _on_element_moved(from_grid_pos: Vector2i, to_grid_pos: Vector2i, _element_type_id: String) -> void:
	# 移动只更新索引与变换，避免 removed+spawned 两次处理。
	# 前提：from 必然先经 element_spawned 记录（元素先生成后才会移动），缺失时防御性跳过
	var element_type: ElementTypeData = _element_visuals.get(from_grid_pos)
	if element_type != null:
		_element_visuals.erase(from_grid_pos)
		_element_visuals[to_grid_pos] = element_type
	if not _instance_index.has(from_grid_pos):
		return
	var idx: int = _instance_index[from_grid_pos]
	_instance_index.erase(from_grid_pos)
	_instance_index[to_grid_pos] = idx
	_pos_by_index[idx] = to_grid_pos
	var instance_transform := Transform2D(0.0, _grid_to_world(to_grid_pos))
	_border_layer.multimesh.set_instance_transform_2d(idx, instance_transform)
	_fill_layer.multimesh.set_instance_transform_2d(idx, instance_transform)