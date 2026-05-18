class_name GridUtils
extends RefCounted


static func get_line_cells(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dx := to_pos.x - from_pos.x
	var dy := to_pos.y - from_pos.y

	if abs(dx) >= abs(dy):
		var y := from_pos.y
		var start_x := mini(from_pos.x, to_pos.x)
		var end_x := maxi(from_pos.x, to_pos.x)
		for x in range(start_x, end_x + 1):
			cells.append(Vector2i(x, y))
	else:
		var x := from_pos.x
		var start_y := mini(from_pos.y, to_pos.y)
		var end_y := maxi(from_pos.y, to_pos.y)
		for y in range(start_y, end_y + 1):
			cells.append(Vector2i(x, y))

	return cells


static func get_l_cells(from_pos: Vector2i, to_pos: Vector2i, corner_first_horizontal: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var corner: Vector2i
	if corner_first_horizontal:
		corner = Vector2i(to_pos.x, from_pos.y)
	else:
		corner = Vector2i(from_pos.x, to_pos.y)

	var seg1 := get_line_cells(from_pos, corner)
	var seg2 := get_line_cells(corner, to_pos)
	cells.append_array(seg1)
	for pos in seg2:
		if pos != corner:
			cells.append(pos)
	return cells


static func get_rect_cells(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var min_x := mini(from_pos.x, to_pos.x)
	var max_x := maxi(from_pos.x, to_pos.x)
	var min_y := mini(from_pos.y, to_pos.y)
	var max_y := maxi(from_pos.y, to_pos.y)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			cells.append(Vector2i(x, y))

	return cells


static func get_paste_line_anchors(from_pos: Vector2i, to_pos: Vector2i, unit_width: int, unit_height: int) -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	var dx := to_pos.x - from_pos.x
	var dy := to_pos.y - from_pos.y

	if abs(dx) >= abs(dy):
		var y := from_pos.y
		var start_x := mini(from_pos.x, to_pos.x)
		var end_x := maxi(from_pos.x, to_pos.x)
		var step := maxi(unit_width, 1)
		var x := start_x
		while x <= end_x:
			anchors.append(Vector2i(x, y))
			x += step
	else:
		var x := from_pos.x
		var start_y := mini(from_pos.y, to_pos.y)
		var end_y := maxi(from_pos.y, to_pos.y)
		var step := maxi(unit_height, 1)
		var y := start_y
		while y <= end_y:
			anchors.append(Vector2i(x, y))
			y += step

	return anchors


static func get_building_node_name(grid_pos: Vector2i) -> String:
	return "Building_%d_%d" % [grid_pos.x, grid_pos.y]
