extends GutTest

const TOOLTIP_SCENE := preload("res://scenes/building_tooltip.tscn")

var _tooltip: BuildingTooltip = null

func before_each():
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child_autoqfree(_tooltip)


func test_initial_hidden():
	assert_false(_tooltip.visible, "初始应隐藏")


func test_on_building_hovered_shows():
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/container_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip.visible, "收到 hovered 信号后应显示")


func test_on_building_hover_exited_hides():
	_tooltip.show()
	_tooltip._on_building_hover_exited(Vector2i(0, 0))
	assert_false(_tooltip.visible, "收到 exited 信号后应隐藏")


func test_update_content_shows_building_name():
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/container_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_eq(_tooltip._name_label.text, "容器", "应显示建筑名称 '容器'")


func test_update_content_shows_summary():
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/pipe_node.gd"))
	mock_node.capacity = 3
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip._summary_container.get_child_count() > 0, "摘要容器应有子节点")


func test_update_content_empty_summary_shows_placeholder():
	var mock_node := Node2D.new()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	var found = false
	for child in _tooltip._summary_container.get_children():
		if child is Label and child.text == "暂无属性":
			found = true
			break
	assert_true(found, "无摘要时应显示 '暂无属性'")


func test_expand_toggle():
	_tooltip._is_expanded = false
	assert_false(_tooltip._is_expanded, "初始未展开")
	_tooltip._on_expand_pressed()
	assert_true(_tooltip._is_expanded, "展开后 _is_expanded 应为 true")
	assert_true(_tooltip._details_container.visible, "展开后 details_container 应可见")
	_tooltip._on_expand_pressed()
	assert_false(_tooltip._is_expanded, "再次点击应收起")
