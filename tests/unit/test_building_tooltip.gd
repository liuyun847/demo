extends GutTest

const TOOLTIP_SCENE := preload("res://scenes/building_tooltip.tscn")

var _tooltip: BuildingTooltip = null

func before_each() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child_autoqfree(_tooltip)


func test_initial_hidden() -> void:
	assert_false(_tooltip.visible, "初始应隐藏")


func test_on_building_hovered_shows() -> void:
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/pipe_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip.visible, "收到 hovered 信号后应显示")


func test_on_building_hover_exited_hides() -> void:
	_tooltip.show()
	_tooltip._on_building_hover_exited(Vector2i(0, 0))
	assert_false(_tooltip.visible, "收到 exited 信号后应隐藏")


func test_update_content_shows_building_name() -> void:
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/pipe_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_eq(_tooltip._name_label.text, "管道", "应显示建筑名称 '管道'")


func test_update_content_shows_summary() -> void:
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/pipe_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip._summary_container.get_child_count() > 0, "摘要容器应有子节点")


func test_update_content_empty_summary_shows_placeholder() -> void:
	var mock_node := Node2D.new()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	var found: bool = false
	for child: Node in _tooltip._summary_container.get_children():
		if child is Label and child.text == "暂无属性":
			found = true
			break
	assert_true(found, "无摘要时应显示 '暂无属性'")


func test_on_building_removed_hides() -> void:
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/pipe_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip.visible, "hovered 后应显示")
	_tooltip._on_building_removed(Vector2i(0, 0))
	assert_false(_tooltip.visible, "收到 building_removed 后应隐藏")
	assert_null(_tooltip._target_node, "_target_node 应置为 null")


## 需求 3：短摘要文本按自然宽度显示，不应设置固定最小宽度（否则撑出大量空白）
func test_summary_label_short_text_natural_width() -> void:
	var label: Label = _tooltip._create_summary_label("产出: 免费", Color(0.1, 0.1, 0.1))
	add_child_autoqfree(label)
	assert_eq(label.custom_minimum_size.x, 0.0, "短文本不应设置固定最小宽度")


## 需求 3：超长摘要文本应限制宽度触发换行，防止卡片被无限撑宽
func test_summary_label_long_text_limited_width() -> void:
	var long_text := "这是一段非常长的描述文本，用来验证超过最大宽度限制时启用自动换行，避免详情卡片被撑得过宽"
	var label: Label = _tooltip._create_summary_label(long_text, Color(0.1, 0.1, 0.1))
	add_child_autoqfree(label)
	assert_eq(label.custom_minimum_size.x, BuildingTooltip.MAX_CONTENT_WIDTH, "超长文本应限制宽度为 MAX_CONTENT_WIDTH")


## 回归测试：连续 hover 时旧摘要 Label 应立即移除，不得残留进尺寸计算（否则卡片高度被叠加内容撑高）
func test_repeated_hover_removes_old_labels() -> void:
	var mock_node := Node2D.new()
	mock_node.set_script(preload("res://scripts/building/pipe_node.gd"))
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	_tooltip._on_building_hovered(Vector2i(1, 0), mock_node)
	assert_eq(_tooltip._summary_container.get_child_count(), 1, "第二次 hover 应立即移除旧摘要 label，不累积")
	await get_tree().process_frame
	assert_lt(_tooltip.size.y, 200.0, "卡片高度应贴合内容（管道仅 1 行摘要），不应被残留 label 撑高")
