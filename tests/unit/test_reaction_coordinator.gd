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
		[GameConfig.EMITTER_TYPE_ID,   {"category": BuildingTypeData.Category.EMITTER}],
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


## 测试1: emitter 同时直连 core 和 pipe 网络时只被激活一次（BFS 去重）
## 布局：核心占据 (-1,-1)..(0,0)；管道 (1,0) 邻接核心格 (0,0)；
## 发射器 (1,-1) 同时邻接核心格 (0,-1) 和管道 (1,0)。
## 直连分支与 BFS 分支都试图收集该发射器，全局 visited 字典应保证其只出现一次。
func test_emitter_direct_and_pipe_no_duplicate() -> void:
	var bm: BuildingManager = autoqfree(_BM.new())
	var pr: PipeRenderSystem = autoqfree(_PRS.new())
	pr.name = "PipeRenderSystem"
	bm.add_child(pr)
	add_child_autoqfree(bm)

	# 管道 (1,0) 邻接核心格 (0,0)
	bm.place_building(Vector2i(1, 0), GameConfig.PIPE_TYPE_ID)
	# 发射器 (1,-1) 同时邻接核心格 (0,-1) 与管道 (1,0)
	bm.place_building(Vector2i(1, -1), GameConfig.EMITTER_TYPE_ID)

	# 创建独立的 ReactionCoordinator，不加入场景树（避免 _ready 的 Timer/EventBus 副作用），
	# 直接调用 _rebuild_networks 验证 BFS 去重逻辑
	var coord: ReactionCoordinator = autoqfree(ReactionCoordinator.new())
	coord.init(bm)
	coord._rebuild_networks()

	# 统计所有网络中的 emitter 总数（应只被收集一次）
	var total_emitters: int = 0
	var networks_with_emitter: int = 0
	for network: Dictionary in coord._cached_networks:
		var emitters: Array = network["emitters"]
		total_emitters += emitters.size()
		if not emitters.is_empty():
			networks_with_emitter += 1

	assert_eq(total_emitters, 1, "emitter 应只被收集一次（BFS 去重）")
	assert_eq(networks_with_emitter, 1, "emitter 应只属于一个网络，不被直连与 BFS 重复加入")
