class_name GhostPreviewManager
extends Node2D

var _ghost_layers: Dictionary = {}
var paste_ghost_types: Dictionary[Vector2i, String] = {}
## 粘贴预览逐格朝向（来自剪贴板条目 direction，缺省为东）
var paste_ghost_dirs: Dictionary[Vector2i, int] = {}
## 放置预览逐格类型/朝向（拖拽路径每格可有不同朝向；无信息时不画箭头）
var ghost_types: Dictionary[Vector2i, String] = {}
var ghost_dirs: Dictionary[Vector2i, int] = {}

## 端口箭头颜色：输入 = 绿色（指向格内），输出 = 白色（指向格外）
const INPUT_ARROW_COLOR: Color = Color(0.35, 0.9, 0.55, 0.95)
const OUTPUT_ARROW_COLOR: Color = Color(1, 1, 1, 0.95)
## 端口箭头几何（px）：tip 伸出长度 / base 回缩长度 / 半翼宽
const ARROW_TIP_LEN: float = 12.0
const ARROW_BASE_LEN: float = 6.0
const ARROW_HALF_W: float = 5.0


func _ready() -> void:
	EventBus.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	if EventBus.selection_changed.is_connected(_on_selection_changed):
		EventBus.selection_changed.disconnect(_on_selection_changed)


func _on_selection_changed(cells: Array[Vector2i]) -> void:
	_ghost_layers["selected"] = cells
	queue_redraw()


func set_selected_cells(cells: Array[Vector2i]) -> void:
	_ghost_layers["selected"] = cells
	queue_redraw()


## 显示放置预览。type_id + dirs 提供逐格类型/朝向（dirs 长度须等于 cells 长度），
## 用于画输入/输出方向箭头；缺省则不画箭头（与旧行为一致）。
func show_ghost(cells: Array[Vector2i], type_id: String = "", dirs: Array[int] = []) -> void:
	_ghost_layers["ghost"] = cells
	ghost_types.clear()
	ghost_dirs.clear()
	if not type_id.is_empty() and dirs.size() == cells.size():
		for i in range(cells.size()):
			ghost_types[cells[i]] = type_id
			ghost_dirs[cells[i]] = dirs[i]
	queue_redraw()


func hide_ghost() -> void:
	_ghost_layers.erase("ghost")
	ghost_types.clear()
	ghost_dirs.clear()
	queue_redraw()


func show_remove_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["remove_ghost"] = cells
	queue_redraw()


func hide_remove_ghost() -> void:
	_ghost_layers.erase("remove_ghost")
	queue_redraw()


func show_select_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["select_ghost"] = cells
	queue_redraw()


func hide_select_ghost() -> void:
	_ghost_layers.erase("select_ghost")
	queue_redraw()


func show_deselect_ghost(cells: Array[Vector2i]) -> void:
	_ghost_layers["deselect_ghost"] = cells
	queue_redraw()


func hide_deselect_ghost() -> void:
	_ghost_layers.erase("deselect_ghost")
	queue_redraw()


func set_paste_preview_line(anchors: Array[Vector2i], clipboard: Dictionary) -> void:
	_ghost_layers.erase("paste_ghost")
	paste_ghost_types.clear()
	paste_ghost_dirs.clear()
	if clipboard.is_empty() or not clipboard.has("buildings"):
		queue_redraw()
		return
	var clip_buildings: Array = clipboard["buildings"]
	var paste_ghost_cells: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for anchor: Vector2i in anchors:
		for item: Dictionary in clip_buildings:
			var grid_pos: Vector2i = anchor + item["offset"]
			if not seen.has(grid_pos):
				seen[grid_pos] = true
				paste_ghost_cells.append(grid_pos)
				paste_ghost_types[grid_pos] = item["type"]
				paste_ghost_dirs[grid_pos] = int(item.get("direction", MachineSpec.DIR_E))
	_ghost_layers["paste_ghost"] = paste_ghost_cells
	queue_redraw()


func clear_paste_preview() -> void:
	_ghost_layers.erase("paste_ghost")
	paste_ghost_types.clear()
	paste_ghost_dirs.clear()
	queue_redraw()


func get_layer_cells(layer_name: String) -> Array:
	return _ghost_layers.get(layer_name, [])


func _draw() -> void:
	var bm := _get_building_manager()

	var ghost_cells: Array = _ghost_layers.get("ghost", [])
	if not ghost_cells.is_empty():
		var ghost_fill := Color(1, 1, 1, GameConfig.GHOST_ALPHA)
		var filtered_cells: Array[Vector2i] = []
		for grid_pos: Vector2i in ghost_cells:
			# 复用 BuildingManager.can_place 同一规则：空格可放置；
			# 传送带格仅当分流器可转换时允许预览（否则已占用格不显示）
			if bm == null or bm.can_place(grid_pos, str(ghost_types.get(grid_pos, ""))):
				filtered_cells.append(grid_pos)
		_draw_cell_highlight(filtered_cells, ghost_fill, Color.WHITE, true, 2.0)
		_draw_port_arrows_for_cells(filtered_cells, ghost_types, ghost_dirs)

	var remove_ghost_cells: Array = _ghost_layers.get("remove_ghost", [])
	if not remove_ghost_cells.is_empty():
		_draw_cell_highlight(remove_ghost_cells, Color(1, 0, 0, GameConfig.REMOVE_GHOST_ALPHA), Color.RED, false, 2.0)
		# 删除预览不画端口箭头：红色语义=将被移除，叠加方向箭头视觉混杂

	var select_ghost_cells: Array = _ghost_layers.get("select_ghost", [])
	if not select_ghost_cells.is_empty():
		_draw_cell_highlight(select_ghost_cells, GameConfig.SELECTION_HIGHLIGHT_COLOR, GameConfig.SELECTION_BORDER_COLOR, false, 2.0)
		_draw_port_arrows_from_manager(select_ghost_cells)

	var deselect_ghost_cells: Array = _ghost_layers.get("deselect_ghost", [])
	if not deselect_ghost_cells.is_empty():
		_draw_cell_highlight(deselect_ghost_cells, Color(0.6, 0.2, 0.2, 0.3), Color(0.6, 0.2, 0.2, 0.8), false, 2.0)
		_draw_port_arrows_from_manager(deselect_ghost_cells)

	var selected_cells: Array = _ghost_layers.get("selected", [])
	if not selected_cells.is_empty():
		_draw_cell_highlight(selected_cells, GameConfig.SELECTION_HIGHLIGHT_COLOR, GameConfig.SELECTION_BORDER_COLOR, false, 2.0)
		_draw_port_arrows_from_manager(selected_cells)

	var paste_ghost_cells: Array = _ghost_layers.get("paste_ghost", [])
	if not paste_ghost_cells.is_empty():
		for grid_pos: Vector2i in paste_ghost_cells:
			var building_type: String = paste_ghost_types.get(grid_pos, "default")
			var color := BuildingTypeManager.get_building_color(building_type)
			color.a = GameConfig.PASTE_GHOST_ALPHA
			var border_color := color
			border_color.a = mini(color.a + 0.35, 1.0)
			_draw_cell_highlight([grid_pos], color, border_color, true, 2.0)
		_draw_port_arrows_for_cells(paste_ghost_cells, paste_ghost_types, paste_ghost_dirs)


func _draw_cell_highlight(cells: Array, fill_color: Color, border_color: Color, use_building_size: bool = false, border_width: float = 2.0) -> void:
	var cell_size: float = GameConfig.BUILDING_SIZE if use_building_size else GameConfig.CELL_SIZE
	var half_size: float = cell_size / 2.0
	for grid_pos: Vector2i in cells:
		var world_pos := GridCoordinate.grid_to_world(grid_pos)
		var rect := Rect2(world_pos - Vector2(half_size, half_size), Vector2(cell_size, cell_size))
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, border_width)


## 从存储字典绘制端口箭头（放置/粘贴预览：类型/朝向由调用方提供）
func _draw_port_arrows_for_cells(cells: Array, types: Dictionary, dirs: Dictionary) -> void:
	for grid_pos: Vector2i in cells:
		if not types.has(grid_pos) or not dirs.has(grid_pos):
			continue
		_draw_port_arrows(grid_pos, str(types[grid_pos]), int(dirs[grid_pos]))


## 从 BuildingManager 查询已有建筑的端口箭头（选中/框选/删除预览）
func _draw_port_arrows_from_manager(cells: Array) -> void:
	var bm := _get_building_manager()
	if bm == null:
		return
	for grid_pos: Vector2i in cells:
		if not bm.has_building(grid_pos):
			continue
		var data: BuildingData = bm.get_building_data(grid_pos)
		if data == null:
			continue
		_draw_port_arrows(grid_pos, data.building_type, data.direction)


## 按建筑类型+朝向画端口箭头：输入口箭头指向格内（收），输出口箭头指向格外（出）
func _draw_port_arrows(grid_pos: Vector2i, type_id: String, dir: int) -> void:
	if type_id.is_empty() or not MachineSpec.is_known(type_id):
		return
	# 四向端口类型（分流器/一体建筑/垃圾桶）：方向完全对称，不画 8 个进出箭头
	# （视觉混杂），改画 4 个中性端口标记
	if MachineSpec.is_four_way_port_type(type_id):
		_draw_four_way_port_marks(grid_pos)
		return
	var ports: Dictionary = MachineSpec.get_port_offsets(type_id, dir)
	var world_center := GridCoordinate.grid_to_world(grid_pos)
	for off: Vector2i in ports["ins"]:
		_draw_edge_arrow(world_center, off, true)
	for off: Vector2i in ports["outs"]:
		_draw_edge_arrow(world_center, off, false)

## 四向端口类型：4 边中点画中性小圆点（不区分进出）
func _draw_four_way_port_marks(grid_pos: Vector2i) -> void:
	var world_center := GridCoordinate.grid_to_world(grid_pos)
	for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var edge_mid := world_center + Vector2(off) * (GameConfig.CELL_SIZE / 2.0)
		draw_circle(edge_mid, 3.0, Color(1, 1, 1, 0.9))


## 在建筑格边中点画小三角箭头：is_input 尖朝格内，否则尖朝端口方向
func _draw_edge_arrow(world_center: Vector2, port_off: Vector2i, is_input: bool) -> void:
	var dir_vec := Vector2(port_off.x, port_off.y)
	var edge_mid := world_center + dir_vec * (GameConfig.CELL_SIZE / 2.0)
	var arrow_dir := -dir_vec if is_input else dir_vec
	var tip := edge_mid + arrow_dir * ARROW_TIP_LEN
	var base := edge_mid - arrow_dir * ARROW_BASE_LEN
	var perp := Vector2(-dir_vec.y, dir_vec.x)
	var a := base + perp * ARROW_HALF_W
	var b := base - perp * ARROW_HALF_W
	draw_colored_polygon(
		PackedVector2Array([tip, a, b]),
		INPUT_ARROW_COLOR if is_input else OUTPUT_ARROW_COLOR
	)


func _get_building_manager() -> BuildingManager:
	var parent := get_parent()
	if parent is BuildingManager:
		return parent
	return null