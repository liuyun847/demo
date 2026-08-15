extends GutTest

## ElementRenderer MultiMesh 实例化渲染（方向 C）的单元测试。
## 注意：headless 模式（GUT 运行环境）的 RenderingServer 不存储 MultiMesh
## 实例变换/颜色数据（GPU 缓冲在 dummy 渲染器下不分配），因此本测试只验证
## 逻辑层状态（索引映射、可见实例数、视觉字典），GPU 数据流已在非 headless 下实测确认。

var _renderer: ElementRenderer = null

func before_each() -> void:
	_renderer = autoqfree(ElementRenderer.new())
	add_child_autoqfree(_renderer)

func after_each() -> void:
	_renderer = null

func test_spawn_creates_instance() -> void:
	var pos := Vector2i(3, 4)
	EventBus.element_spawned.emit(pos, "water")

	assert_true(_renderer._element_visuals.has(pos), "spawn 后应记录元素视觉")
	assert_true(_renderer._instance_index.has(pos), "spawn 后应建立实例索引")
	assert_eq(_renderer._instance_index[pos], 0, "首个实例索引应为 0")
	assert_eq(_renderer._pos_by_index[0], pos, "索引 0 应映射回格子坐标")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, 1, "可见实例数应为 1")

func test_spawn_sets_colors() -> void:
	var pos := Vector2i(0, 0)
	EventBus.element_spawned.emit(pos, "water")
	var water: ElementTypeData = ElementRegistry.get_element_type("water")
	assert_eq(_renderer._element_visuals[pos], water, "视觉字典应记录 water 类型")

func test_move_updates_index() -> void:
	var from := Vector2i(1, 1)
	var to := Vector2i(1, 2)
	EventBus.element_spawned.emit(from, "water")
	EventBus.element_moved.emit(from, to, "water")

	assert_false(_renderer._instance_index.has(from), "移动后原位置索引应移除")
	assert_true(_renderer._instance_index.has(to), "移动后目标位置应建立索引")
	var idx: int = _renderer._instance_index[to]
	assert_eq(idx, 0, "移动后实例索引应保持不变（同一实例）")
	assert_eq(_renderer._pos_by_index[idx], to, "索引应映射到新格子")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, 1, "移动不改变实例总数")

func test_remove_decrements_visible_count() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(2, 0)
	EventBus.element_spawned.emit(a, "water")
	EventBus.element_spawned.emit(b, "fire")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, 2, "spawn 两个元素后可见数为 2")

	EventBus.element_removed.emit(a, "water")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, 1, "移除后可见数应为 1")
	assert_false(_renderer._instance_index.has(a), "移除后索引应清除")

	# swap-last 后剩余实例仍正确（b 应位于索引 0）
	var b_idx: int = _renderer._instance_index[b]
	assert_eq(b_idx, 0, "swap-last 后剩余实例应回填到 0")
	assert_eq(_renderer._pos_by_index[0], b, "索引 0 应映射到剩余元素")

func test_remove_last_element() -> void:
	var pos := Vector2i(0, 0)
	EventBus.element_spawned.emit(pos, "water")
	EventBus.element_removed.emit(pos, "water")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, 0, "移除唯一元素后可见数应为 0")
	assert_true(_renderer._instance_index.is_empty(), "移除后索引应清空")

func test_clear_all_resets() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(5, 5)
	EventBus.element_spawned.emit(a, "water")
	EventBus.element_spawned.emit(b, "fire")
	_renderer.clear_all()
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, 0, "clear_all 后可见数应为 0")
	assert_true(_renderer._instance_index.is_empty(), "clear_all 后索引应清空")
	assert_true(_renderer._element_visuals.is_empty(), "clear_all 后视觉字典应清空")

## 回归测试: 实例数越过初始容量(64)触发扩容后，索引映射与可见数保持一致。
## 背景: Godot 的 MultiMesh.instance_count setter 扩容会清空 GPU 实例数据（非 headless 下
## 元素会全部塌缩到原点），_ensure_capacity 已改为扩容后重写全部实例数据。
## headless 下 GPU 缓冲不存数据，此处守护扩容路径的逻辑层一致性（索引/可见数/视觉字典）。
func test_capacity_growth_keeps_index_consistency() -> void:
	var count := 80  # 超过初始容量 64，触发 64->128 扩容
	for i in range(count):
		EventBus.element_spawned.emit(Vector2i(i, 0), "water")

	assert_eq(_renderer._instance_index.size(), count, "扩容后实例索引数应等于元素数")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, count, "扩容后可见实例数应等于元素数")
	assert_eq(_renderer._element_visuals.size(), count, "扩容后视觉字典应完整")

	# 扩容后移动索引 79 的元素：索引应保持不变，映射应更新
	EventBus.element_moved.emit(Vector2i(79, 0), Vector2i(80, 0), "water")
	assert_false(_renderer._instance_index.has(Vector2i(79, 0)), "移动后原位置索引应移除")
	assert_true(_renderer._instance_index.has(Vector2i(80, 0)), "移动后目标位置应建立索引")
	assert_eq(_renderer._instance_index[Vector2i(80, 0)], 79, "移动不改变实例索引")
	assert_eq(_renderer._pos_by_index[79], Vector2i(80, 0), "索引映射应指向新格子")

	# 扩容后移除索引 0：swap-last 回填后映射仍一致
	EventBus.element_removed.emit(Vector2i(0, 0), "water")
	assert_eq(_renderer._instance_index.size(), count - 1, "移除后实例索引数应减一")
	assert_eq(_renderer._fill_layer.multimesh.visible_instance_count, count - 1, "移除后可见数应减一")
	assert_false(_renderer._instance_index.has(Vector2i(0, 0)), "移除后原位置索引应清除")
	var last_pos := Vector2i(80, 0)
	assert_eq(_renderer._instance_index[last_pos], 0, "swap-last 后剩余元素应回填到 0")
	assert_eq(_renderer._pos_by_index[0], last_pos, "索引 0 应映射到剩余元素")
