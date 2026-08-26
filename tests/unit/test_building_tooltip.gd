extends GutTest

const TOOLTIP_SCENE := preload("res://scenes/building_tooltip.tscn")

var _tooltip: BuildingTooltip = null

func before_each() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child_autoqfree(_tooltip)


func test_initial_hidden() -> void:
	assert_false(_tooltip.visible, "初始应隐藏")


func _make_belt_node() -> Node2D:
	var node := Node2D.new()
	node.set_script(preload("res://scripts/machine/belt_node.gd"))
	return node

func test_on_building_hovered_shows() -> void:
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip.visible, "收到 hovered 信号后应显示")


func test_on_building_hover_exited_hides() -> void:
	_tooltip.show()
	_tooltip._on_building_hover_exited(Vector2i(0, 0))
	assert_false(_tooltip.visible, "收到 exited 信号后应隐藏")


func test_update_content_shows_building_name() -> void:
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_eq(_tooltip._name_label.text, "传送带", "应显示建筑名称 '传送带'")


func test_update_content_shows_summary() -> void:
	var mock_node := _make_belt_node()
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
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	assert_true(_tooltip.visible, "hovered 后应显示")
	_tooltip._on_building_removed(Vector2i(0, 0))
	assert_false(_tooltip.visible, "收到 building_removed 后应隐藏")
	assert_null(_tooltip._target_node, "_target_node 应置为 null")


## 需求 3：短摘要文本按自然宽度显示，不应设置固定最小宽度（否则撑出大量空白）
func test_summary_label_short_text_natural_width() -> void:
	var label: Label = _tooltip._create_summary_label("行为: 推进物品", Color(0.1, 0.1, 0.1))
	add_child_autoqfree(label)
	assert_eq(label.custom_minimum_size.x, 0.0, "短文本不应设置固定最小宽度")
	# autowrap 下 Label 的 min size 宽度恒为 1（可压缩到任意窄），会把卡片挤成竖条；
	# 短文本必须关闭 autowrap，让 min size 宽度 = 文本自然宽度
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_OFF, "短文本不应开启 autowrap")
	assert_gt(label.get_minimum_size().x, 10.0, "短文本 min size 宽度应为自然宽度而非 1（防止卡片塌缩成窄条）")


## 回归测试（宽度塌缩）：悬停后摘要应单行显示，卡片尺寸贴合内容。
## 曾因短文本开启 autowrap 导致 VBox 塌缩到标题宽度、摘要被挤成 6 行竖条、
## 面板尺寸与内容错位（文字与面板分离）。
func test_hover_summary_single_line_and_size_fits() -> void:
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary_label: Label = _tooltip._summary_container.get_child(0)
	assert_eq(summary_label.get_line_count(), 1, "短摘要应单行显示，不得被挤成多行竖条")
	# 卡片宽度应容纳最长摘要行（自然宽度 + 左右边距 16px），用相对断言避免依赖字体度量阈值
	var margin_w := _tooltip._margin.get_theme_constant("margin_left") + _tooltip._margin.get_theme_constant("margin_right")
	var content_min_x: float = _tooltip._summary_container.get_parent().get_combined_minimum_size().x
	assert_lt(absf(_tooltip.size.x - (content_min_x + margin_w)), 2.0, "卡片宽度应贴合最长摘要行，不得塌缩成窄条")
	assert_lt(_tooltip.size.y, 200.0, "卡片高度应贴合内容")


## 回归测试（代次守卫）：快速连续 hover 不同建筑时，旧续体不得用过期内容覆盖新布局。
## 曾因多个 in-flight await 续体交错恢复导致面板尺寸/位置与当前内容错位。
func test_rapid_hover_uses_latest_content_size() -> void:
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	var mock_node2 := Node2D.new()
	add_child_autoqfree(mock_node2)
	# 第一次 hover（传送带），随即切到无摘要建筑（占位文本），旧续体应作废
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	_tooltip._on_building_hovered(Vector2i(1, 0), mock_node2)
	await get_tree().process_frame
	await get_tree().process_frame
	var placeholder: Label = _tooltip._summary_container.get_child(0)
	assert_eq(placeholder.text, "暂无属性", "最终内容应为最后一次悬停的建筑")
	# 卡片尺寸应贴合最后一次悬停的内容（占位卡片短小）；
	# 若旧续体（传送带 3 行）覆盖 offsets，尺寸将不再贴合内容，此断言会检出
	var margin_h := _tooltip._margin.get_theme_constant("margin_top") + _tooltip._margin.get_theme_constant("margin_bottom")
	var vbox: VBoxContainer = _tooltip._summary_container.get_parent()
	assert_lt(absf(_tooltip.size.y - (vbox.get_combined_minimum_size().y + margin_h)), 2.0, "最终尺寸应贴合最后一次悬停的内容")


## 需求 3：超长摘要文本应限制宽度触发换行，防止卡片被无限撑宽
func test_summary_label_long_text_limited_width() -> void:
	var long_text := "这是一段非常长的描述文本，用来验证超过最大宽度限制时启用自动换行，避免详情卡片被撑得过宽"
	var label: Label = _tooltip._create_summary_label(long_text, Color(0.1, 0.1, 0.1))
	add_child_autoqfree(label)
	assert_eq(label.custom_minimum_size.x, BuildingTooltip.MAX_CONTENT_WIDTH, "超长文本应限制宽度为 MAX_CONTENT_WIDTH")
	# 仅限宽不开 autowrap 时 min size 宽度仍是全文本自然宽（远大于 200），需求会回归
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "超长文本应开启 autowrap 才能在限宽内换行")


## 回归测试：连续 hover 时旧摘要 Label 应立即移除，不得残留进尺寸计算（否则卡片高度被叠加内容撑高）
func test_repeated_hover_removes_old_labels() -> void:
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	_tooltip._on_building_hovered(Vector2i(1, 0), mock_node)
	# 传送带摘要共 3 行（行为/方向/背压；name 键由标题显示，摘要跳过）；若不移除旧 label 会累积为 6
	assert_eq(_tooltip._summary_container.get_child_count(), 3, "第二次 hover 应立即移除旧摘要 label，不累积")
	await get_tree().process_frame
	assert_lt(_tooltip.size.y, 200.0, "卡片高度应贴合内容（传送带 3 行摘要），不应被残留 label 撑高")


## 需求 4：摘要不应重复显示建筑名称（标题已显示，name 键跳过）
func test_summary_skips_name_key() -> void:
	var mock_node := _make_belt_node()
	add_child_autoqfree(mock_node)
	_tooltip._on_building_hovered(Vector2i(0, 0), mock_node)
	for child: Node in _tooltip._summary_container.get_children():
		if child is Label:
			var text: String = (child as Label).text
			assert_false(text.begins_with("name"), "摘要不应包含 name 行: %s" % text)
