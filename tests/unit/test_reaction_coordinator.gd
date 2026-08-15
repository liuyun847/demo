extends GutTest

const _BM: GDScript = preload("res://scripts/building/building_manager.gd")
const _PRS: GDScript = preload("res://scripts/building/pipe_render_system.gd")


## Mock 源质服务，隔离测试避免污染全局 EssencePool
class _MockEssence:
	var essence: float = 0.0
	func add(amount: float) -> void:
		essence += amount
	func subtract(amount: float) -> float:
		essence -= amount
		return amount
	func has(amount: float) -> bool:
		return essence >= amount


func before_all() -> void:
	_ensure_building_types_registered()


func _ensure_building_types_registered() -> void:
	if BuildingTypeManager.has_capacity(GameConfig.PIPE_TYPE_ID):
		return
	var types: Array[BuildingTypeData] = []
	var entries: Array = [
		[GameConfig.PIPE_TYPE_ID,      {"category": BuildingTypeData.Category.PIPE}],
		[GameConfig.SOURCE_TYPE_ID,    {"category": BuildingTypeData.Category.SOURCE}],
		[GameConfig.COLLECTOR_TYPE_ID, {"category": BuildingTypeData.Category.COLLECTOR}],
		[GameConfig.BRICK_TYPE_ID,     {}],
	]
	for entry: Array in entries:
		var td := BuildingTypeData.new()
		td.type_id = entry[0]
		var props: Dictionary = entry[1]
		for k: String in props.keys():
			td.set(k, props[k])
		types.append(td)
	BuildingTypeManager.register_all(types)


## 测试1: source 同时直连 core 和 pipe 网络时只被激活一次（BFS 去重）
## 布局：核心占据 (-1,-1)..(0,0)；管道 (1,0) 邻接核心格 (0,0)；
## 源头 (1,-1) 同时邻接核心格 (0,-1) 和管道 (1,0)。
## 直连分支与 BFS 分支都试图收集该源头，全局 visited 字典应保证其只出现一次。
func test_source_direct_and_pipe_no_duplicate() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 管道 (1,0) 邻接核心格 (0,0)
	bm.place_building(Vector2i(1, 0), GameConfig.PIPE_TYPE_ID)
	# 源头 (1,-1) 同时邻接核心格 (0,-1) 与管道 (1,0)
	bm.place_building(Vector2i(1, -1), GameConfig.SOURCE_TYPE_ID)

	# 创建独立的 ReactionCoordinator，不加入场景树（避免 _ready 的 Timer/EventBus 副作用），
	# 直接调用 _rebuild_networks 验证 BFS 去重逻辑
	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	# 统计所有网络中的 source 总数（应只被收集一次）
	var total_sources: int = 0
	var networks_with_source: int = 0
	for network: Dictionary in coord._cached_networks:
		var sources: Array = network["sources"]
		total_sources += sources.size()
		if not sources.is_empty():
			networks_with_source += 1

	assert_eq(total_sources, 1, "source 应只被收集一次（BFS 去重）")
	assert_eq(networks_with_source, 1, "source 应只属于一个网络，不被直连与 BFS 重复加入")


## 测试2: 未连通核心的源头不在激活集合中（不应产出元素）
## 布局：核心占据 (-1,-1)..(0,0)；源头 (5,5) 远离核心，无管道连接
## _collect_active_source_positions 应返回空字典，限制 ElementDiffusion 仅处理连通源头
func test_unconnected_source_not_in_active_positions() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 源头 (5,5) 远离核心，未通过管道连通
	bm.place_building(Vector2i(5, 5), GameConfig.SOURCE_TYPE_ID)

	# 创建独立的 ReactionCoordinator，不加入场景树（避免 _ready 的 Timer/EventBus 副作用）
	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	var active: Dictionary = coord._collect_active_source_positions()
	assert_eq(active.size(), 0, "未连通核心的源头不应出现在激活集合中")
	assert_false(active.has(Vector2i(5, 5)), "远离核心的源头位置不应在激活集合中")


## 测试3: 连通核心的源头在激活集合中
## 布局：核心 (-1,-1)..(0,0)；管道 (1,0) 连通核心；源头 (2,0) 连通管道
func test_connected_source_in_active_positions() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 管道 (1,0) 邻接核心格 (0,0)，源头 (2,0) 邻接管道 (1,0)
	bm.place_building(Vector2i(1, 0), GameConfig.PIPE_TYPE_ID)
	bm.place_building(Vector2i(2, 0), GameConfig.SOURCE_TYPE_ID)

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	var active: Dictionary = coord._collect_active_source_positions()
	assert_eq(active.size(), 1, "连通核心的源头应在激活集合中")
	assert_true(active.has(Vector2i(2, 0)), "连通核心的源头位置应在激活集合中")


## 测试4: 源头-源头链（无管道中介）连通核心
## 布局：核心 (-1,-1)..(0,0)；源头 (1,0) 直连核心格 (0,0)；
## 源头 (2,0) 通过源头 (1,0) 连通核心，无需管道中介。
func test_source_chain_no_pipe_connected() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 源头 (1,0) 邻接核心格 (0,0)，源头 (2,0) 邻接源头 (1,0)
	bm.place_building(Vector2i(1, 0), GameConfig.SOURCE_TYPE_ID)
	bm.place_building(Vector2i(2, 0), GameConfig.SOURCE_TYPE_ID)

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	var active: Dictionary = coord._collect_active_source_positions()
	assert_eq(active.size(), 2, "源头链（无管道）中两个源头都应在激活集合中")
	assert_true(active.has(Vector2i(1, 0)), "直连核心的源头应在激活集合中")
	assert_true(active.has(Vector2i(2, 0)), "通过源头连通的源头应在激活集合中")


## 测试5: 收集器通过源头连通核心
## 布局：核心 (-1,-1)..(0,0)；源头 (1,0) 直连核心；收集器 (2,0) 邻接源头。
func test_collector_via_source_connected() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 源头 (1,0) 邻接核心格 (0,0)，收集器 (2,0) 邻接源头 (1,0)
	bm.place_building(Vector2i(1, 0), GameConfig.SOURCE_TYPE_ID)
	bm.place_building(Vector2i(2, 0), GameConfig.COLLECTOR_TYPE_ID)

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	# 检查网络中有收集器
	var has_collector: bool = false
	for network: Dictionary in coord._cached_networks:
		if network.collectors.size() > 0:
			has_collector = true
			break
	assert_true(has_collector, "收集器应通过源头链连通到核心")


## 测试6: 砖块阻断源头链，不参与连通
## 布局：核心 (-1,-1)..(0,0)；源头 (1,0) 直连核心；
## 砖块 (2,0) 阻断；源头 (3,0) 在砖块另一侧。
func test_brick_blocks_source_chain() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 源头 (1,0) 邻接核心；砖块 (2,0)；源头 (3,0) 在砖块另一侧
	bm.place_building(Vector2i(1, 0), GameConfig.SOURCE_TYPE_ID)
	bm.place_building(Vector2i(2, 0), GameConfig.BRICK_TYPE_ID)
	bm.place_building(Vector2i(3, 0), GameConfig.SOURCE_TYPE_ID)

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	var active: Dictionary = coord._collect_active_source_positions()
	assert_eq(active.size(), 1, "砖块阻断后，只有直连核心的源头被激活")
	assert_true(active.has(Vector2i(1, 0)), "直连核心的源头应在激活集合中")
	assert_false(active.has(Vector2i(3, 0)), "砖块另一侧的源头不应在激活集合中")


## 回归测试：源头切换类型后，旧类型元素体不再被当作有源（不再扩张消耗源质）
## 每 tick 清空水源标记后由 _process_source_buildings 按当前源头类型重建。
func test_source_type_switch_old_elements_lose_source() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	# 停掉 bm 自带 coordinator 的 Timer，避免测试期间自动 tick 干扰断言
	var builtin_coord := bm.get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if builtin_coord:
		builtin_coord._timer.stop()

	# 独立 coordinator，不进树（Timer 不运行），手动 _ready 初始化内部系统，手动 _on_tick 驱动
	var mock := _MockEssence.new()
	mock.essence = 100.0
	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord.set_essence_service(mock)
	coord._ready()

	# 源头 (1,0) 邻接核心格 (0,0)，连通核心；先产出 water
	bm.place_building(Vector2i(1, 0), GameConfig.SOURCE_TYPE_ID)
	var source_node: SourceNode = bm.get_building_node(Vector2i(1, 0)) as SourceNode
	source_node.set_element_type("water")

	# 扩散数 tick，water 向下蔓延（种子 + 扩张）
	for _i in range(3):
		coord._on_tick()
	var water_count_before: int = _count_elements(coord, "water")
	assert_gt(water_count_before, 1, "切换前 water 应已扩散出多个格子")

	# 切换源头类型为 fire，再扩散数 tick
	source_node.set_element_type("fire")
	for _i in range(3):
		coord._on_tick()

	assert_eq(_count_elements(coord, "water"), water_count_before, "切换类型后旧类型 water 不应再增殖扩张")
	# 旧类型元素不应残留水源标记
	var has_water_source: bool = false
	for pos: Vector2i in coord._element_grid.get_all_element_positions():
		if coord._element_grid.get_element_id(pos) == "water" and coord._element_grid.is_source_pos(pos):
			has_water_source = true
			break
	assert_false(has_water_source, "切换类型后 water 元素不应再被标记为水源")


## 测试7: 分帧模拟（方向 D）阶段按序推进，每帧一个阶段
## _on_tick 为同步完整 tick；此处验证 _process 分帧路径的逐帧推进。
func test_frame_split_phases_progress_per_frame() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	# 停掉 bm 自带 coordinator 的 Timer，避免测试期间自动 tick 干扰
	var builtin_coord := bm.get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if builtin_coord:
		builtin_coord._timer.stop()

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._ready()

	coord._tick_pending = true
	coord._process(0.0)  # 帧1：启动 tick 并执行 PREP
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.DIFFUSE, "帧1 后应处于 DIFFUSE 阶段")

	coord._process(0.0)  # 帧2：DIFFUSE
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.REACTIONS, "帧2 后应处于 REACTIONS 阶段")

	coord._process(0.0)  # 帧3：REACTIONS
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.CLEANUP, "帧3 后应处于 CLEANUP 阶段")

	coord._process(0.0)  # 帧4：CLEANUP → tick 完成
	assert_eq(coord._current_phase, -1, "帧4 后 tick 应完成回到空闲")


## 测试8: 分帧模拟（方向 D）进行中的 tick 不被新 Timer 到点中断
## Timer 到点只置 pending 标记；tick 进行中再次到点应合并，而非重启当前 tick
func test_frame_split_pending_does_not_abort_in_progress() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	var builtin_coord := bm.get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if builtin_coord:
		builtin_coord._timer.stop()

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._ready()

	coord._tick_pending = true
	coord._process(0.0)  # 帧1：启动 tick，执行 PREP
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.DIFFUSE, "前置：tick 进行中")

	# tick 进行中 Timer 再次到点（模拟低帧率下 Timer 多次触发）
	coord._tick_pending = true
	coord._process(0.0)  # 不应重启 tick，应继续执行 DIFFUSE
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.REACTIONS, "进行中的 tick 不应被新 pending 中断/重启")

	# 当前 tick 完成后，pending 标记在下一帧启动新 tick
	coord._process(0.0)  # REACTIONS
	coord._process(0.0)  # CLEANUP → 完成
	assert_eq(coord._current_phase, -1, "当前 tick 应完成")
	coord._process(0.0)  # 下一帧：pending 的新 tick 启动
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.DIFFUSE, "pending 新 tick 应在当前完成后启动")


func _count_elements(coord: ReactionCoordinator, element_id: String) -> int:
	var count: int = 0
	for pos: Vector2i in coord._element_grid.get_all_element_positions():
		if coord._element_grid.get_element_id(pos) == element_id:
			count += 1
	return count

## 回归测试: 被建筑围死、无法移动的静态相邻反应对也应触发反应。
## 修复前 REACTIONS 阶段只扫描扩散阶段新产生的脏区域：放置产生的脏区域被 PREP 消费后，
## 若扩散无变化（静态对）则不再产生新脏区域，反应永不触发（旧版全量扫描每 tick 触发）。
func test_static_adjacent_pair_reacts() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	var builtin_coord := bm.get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if builtin_coord:
		builtin_coord._timer.stop()

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord.set_essence_service(_MockEssence.new())
	coord._ready()

	# 砖块围死 (5,0) 与 (6,0)：水+火无法移动，只能通过反应消耗
	for dx in range(-1, 3):
		bm.place_building(Vector2i(5 + dx, -1), GameConfig.BRICK_TYPE_ID)
		bm.place_building(Vector2i(5 + dx, 1), GameConfig.BRICK_TYPE_ID)
	bm.place_building(Vector2i(4, 0), GameConfig.BRICK_TYPE_ID)
	bm.place_building(Vector2i(7, 0), GameConfig.BRICK_TYPE_ID)
	coord._element_grid.set_element(Vector2i(5, 0), "water", 0)
	coord._element_grid.set_element(Vector2i(6, 0), "fire", 0)

	for _i in range(3):
		coord._on_tick()

	assert_eq(_count_elements(coord, "water"), 0, "被围死的静态水+火应发生反应（水被消耗）")
	assert_eq(_count_elements(coord, "fire"), 0, "被围死的静态水+火应发生反应（火被消耗）")
	assert_eq(_count_elements(coord, "steam"), 1, "反应应生成蒸汽")

## 回归测试: 分帧路径（_process 驱动）下静态相邻反应对同样应触发反应
func test_static_adjacent_pair_reacts_split_path() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	var builtin_coord := bm.get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if builtin_coord:
		builtin_coord._timer.stop()

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord.set_essence_service(_MockEssence.new())
	coord._ready()

	for dx in range(-1, 3):
		bm.place_building(Vector2i(5 + dx, -1), GameConfig.BRICK_TYPE_ID)
		bm.place_building(Vector2i(5 + dx, 1), GameConfig.BRICK_TYPE_ID)
	bm.place_building(Vector2i(4, 0), GameConfig.BRICK_TYPE_ID)
	bm.place_building(Vector2i(7, 0), GameConfig.BRICK_TYPE_ID)
	coord._element_grid.set_element(Vector2i(5, 0), "water", 0)
	coord._element_grid.set_element(Vector2i(6, 0), "fire", 0)

	for _i in range(3):
		coord._tick_pending = true
		coord._process(0.0)
		coord._process(0.0)
		coord._process(0.0)
		coord._process(0.0)
		assert_eq(coord._current_phase, -1, "分帧 tick 应在 4 帧内完成")

	assert_eq(_count_elements(coord, "water"), 0, "分帧路径下被围死的静态水+火也应发生反应")
	assert_eq(_count_elements(coord, "fire"), 0, "分帧路径下被围死的静态水+火也应发生反应")
	assert_eq(_count_elements(coord, "steam"), 1, "分帧路径下反应应生成蒸汽")

## 回归测试: 暂停发生在 tick 中途时，剩余阶段被丢弃并全量重标脏区域；
## 恢复后下一 tick 启动并全量重算（避免暂停前的移动/产物变化丢失导致元素卡死）
func test_pause_mid_tick_freezes_and_recovers() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)
	var builtin_coord := bm.get_node_or_null("ReactionCoordinator") as ReactionCoordinator
	if builtin_coord:
		builtin_coord._timer.stop()

	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._ready()
	# 放一个元素使 mark_all_dirty 有内容可标（避开核心占用的 2x2 格，否则 set_element 被建筑拦截）
	coord._element_grid.set_element(Vector2i(5, 5), "water", 5)

	coord._tick_pending = true
	coord._process(0.0)  # 帧1：启动 tick，执行 PREP
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.DIFFUSE, "前置：tick 进行中")

	coord._on_pause_state_changed(true)
	coord._process(0.0)  # 暂停帧：应丢弃剩余阶段
	assert_eq(coord._current_phase, -1, "暂停后应丢弃剩余阶段回到空闲")
	assert_gt(coord._element_grid.get_dirty_count(), 0, "暂停应全量重标脏区域，恢复后重算")

	coord._on_pause_state_changed(false)
	coord._tick_pending = true
	coord._process(0.0)  # 恢复后下一 tick 启动
	assert_eq(coord._current_phase, ReactionCoordinator.TickPhase.DIFFUSE, "恢复后应正常启动新 tick")
