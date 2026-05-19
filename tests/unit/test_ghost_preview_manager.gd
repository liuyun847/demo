extends GutTest

var _gpm: GhostPreviewManager = null

func before_each() -> void:
	if _gpm == null:
		preload("res://scripts/building/ghost_preview_manager.gd")
	_gpm = autoqfree(preload("res://scripts/building/ghost_preview_manager.gd").new())
	add_child_autoqfree(_gpm)

func test_ghost_show_and_hide() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	_gpm.show_ghost(cells)
	assert_eq(_gpm.ghost_cells.size(), 2, "ghost_cells 应有 2 个格子")
	_gpm.hide_ghost()
	assert_true(_gpm.ghost_cells.is_empty(), "隐藏后应为空")

func test_remove_ghost_show_and_hide() -> void:
	var cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 3)]
	_gpm.show_remove_ghost(cells)
	assert_eq(_gpm.remove_ghost_cells.size(), 2)
	_gpm.hide_remove_ghost()
	assert_true(_gpm.remove_ghost_cells.is_empty())

func test_set_selected_cells() -> void:
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2)]
	_gpm.set_selected_cells(cells)
	assert_eq(_gpm.selected_cells.size(), 2, "selected_cells 应有 2 个格子")
	assert_eq(_gpm.selected_cells[0], Vector2i(1, 1))
	var empty: Array[Vector2i] = []
	_gpm.set_selected_cells(empty)
	assert_true(_gpm.selected_cells.is_empty(), "空数组应清空 selected_cells")

func test_set_paste_preview() -> void:
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	_gpm.set_paste_preview(Vector2i(5, 5), clipboard)
	assert_eq(_gpm.paste_ghost_cells.size(), 2, "应计算 2 个粘贴预览格子")
	assert_eq(_gpm.paste_ghost_types.size(), 2, "应有 2 个类型映射")

func test_set_paste_preview_line() -> void:
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
		{"offset": Vector2i(1, 0), "type": "type_02"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	var anchors: Array[Vector2i] = [Vector2i(5, 5), Vector2i(7, 5)]
	_gpm.set_paste_preview_line(anchors, clipboard)
	assert_eq(_gpm.paste_ghost_cells.size(), 4, "2 锚点 × 2 偏移量 = 4 个预览格子")
	assert_eq(_gpm.paste_ghost_types.size(), 4, "应有 4 个类型映射")

func test_set_paste_preview_line_dedup() -> void:
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	var anchors: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 5)]
	_gpm.set_paste_preview_line(anchors, clipboard)
	assert_eq(_gpm.paste_ghost_cells.size(), 1, "重复锚点应去重，只有 1 个预览格子")

func test_clear_paste_preview() -> void:
	var buildings: Array[Dictionary] = [
		{"offset": Vector2i(0, 0), "type": "type_01"},
	]
	var clipboard := {
		"buildings": buildings,
	}
	_gpm.set_paste_preview(Vector2i(0, 0), clipboard)
	assert_false(_gpm.paste_ghost_cells.is_empty(), "设置后应有预览")
	_gpm.clear_paste_preview()
	assert_true(_gpm.paste_ghost_cells.is_empty(), "清除后 paste_ghost_cells 应为空")
	assert_true(_gpm.paste_ghost_types.is_empty(), "清除后 paste_ghost_types 应为空")

func test_select_ghost_show_and_hide() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	_gpm.show_select_ghost(cells)
	assert_eq(_gpm.select_ghost_cells.size(), 3, "应有 3 个选择幽灵格子")
	_gpm.hide_select_ghost()
	assert_true(_gpm.select_ghost_cells.is_empty(), "隐藏后 select_ghost_cells 应为空")

func test_deselect_ghost_show_and_hide() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 3)]
	_gpm.show_deselect_ghost(cells)
	assert_eq(_gpm.deselect_ghost_cells.size(), 1, "应有 1 个取消选择幽灵格子")
	_gpm.hide_deselect_ghost()
	assert_true(_gpm.deselect_ghost_cells.is_empty(), "隐藏后 deselect_ghost_cells 应为空")

func test_set_paste_preview_empty_clipboard() -> void:
	_gpm.set_paste_preview(Vector2i(0, 0), {})
	assert_true(_gpm.paste_ghost_cells.is_empty(), "空剪贴板不应有预览")

func test_set_paste_preview_line_empty_clipboard() -> void:
	var anchors: Array[Vector2i] = [Vector2i(0, 0)]
	_gpm.set_paste_preview_line(anchors, {})
	assert_true(_gpm.paste_ghost_cells.is_empty(), "空剪贴板不应有行预览")
