extends GutTest

const _BM: GDScript = preload("res://scripts/building/building_manager.gd")
const _PRS: GDScript = preload("res://scripts/building/pipe_render_system.gd")


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
