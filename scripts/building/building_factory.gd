class_name BuildingFactory
extends RefCounted

## 建筑工厂：基于 BuildingTypeData.Category 枚举的创建函数注册表。
## 通过 _creators_by_category 字典将 category 枚举映射到对应的创建函数，
## 避免 if-elif 硬编码类型判断，新增建筑类型只需注册新的 category 即可。
static var _placeholder_label_settings: LabelSettings

## category -> 创建函数映射表
## key: BuildingTypeData.Category 枚举值
## value: Callable，签名 (String type_id, Vector2i grid_pos, Vector2 world_pos, String node_name) -> Node2D
static var _creators_by_category: Dictionary = {}


static func _static_init() -> void:
	# 注册已知 category 的创建函数，保持外部接口不变
	_creators_by_category[BuildingTypeData.Category.PIPE] = Callable(BuildingFactory, "_create_pipe")
	_creators_by_category[BuildingTypeData.Category.BRICK] = Callable(BuildingFactory, "_create_brick")
	_creators_by_category[BuildingTypeData.Category.EMITTER] = Callable(BuildingFactory, "_create_emitter")
	_creators_by_category[BuildingTypeData.Category.COLLECTOR] = Callable(BuildingFactory, "_create_collector")


static func _get_placeholder_label_settings() -> LabelSettings:
	if _placeholder_label_settings == null:
		_placeholder_label_settings = LabelSettings.new()
		_placeholder_label_settings.font_size = 12
		_placeholder_label_settings.font_color = Color.WHITE
	return _placeholder_label_settings


## 统一签名的创建函数：所有 _create_* 方法都接收 (type_id, grid_pos, world_pos, node_name)。
## type_id 在部分方法中未使用（带下划线前缀），保持签名一致以便注册表统一调用。
static func _create_pipe(_type_id: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var pipe := PipeNode.new()
	pipe.name = node_name
	pipe.global_position = world_pos
	pipe.grid_position = grid_pos
	return pipe


static func _create_brick(_type_id: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var brick := BrickNode.new()
	brick.name = node_name
	brick.global_position = world_pos
	brick.grid_position = grid_pos
	return brick


static func _create_emitter(_type_id: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var emitter := EmitterNode.new()
	emitter.name = node_name
	emitter.global_position = world_pos
	emitter.grid_position = grid_pos
	return emitter


static func _create_collector(_type_id: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var collector := CollectorNode.new()
	collector.name = node_name
	collector.global_position = world_pos
	collector.grid_position = grid_pos
	return collector


## 占位建筑：GENERIC 类别或未注册类型走此分支，显示带颜色框和序号标签
static func _create_placeholder(building_type: String, _grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var idx := 0
	if building_type.begins_with("type_"):
		idx = building_type.substr(5).to_int()
	var placeholder := Node2D.new()
	placeholder.name = node_name
	placeholder.global_position = world_pos
	placeholder.set_meta("building_type", building_type)
	var half_size := GameConfig.BUILDING_SIZE / 2.0
	var box := ColorRect.new()
	box.size = Vector2(GameConfig.BUILDING_SIZE, GameConfig.BUILDING_SIZE)
	box.position = Vector2(-half_size, -half_size)
	# 复用 BuildingTypeManager.get_building_color，避免颜色映射逻辑重复
	var bg_color: Color = BuildingTypeManager.get_building_color(building_type)
	bg_color.a = 0.3
	box.color = bg_color
	placeholder.add_child(box)
	var label := Label.new()
	label.text = "占位-%d" % idx if idx > 0 else "占位"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(GameConfig.BUILDING_SIZE, GameConfig.BUILDING_SIZE)
	label.position = Vector2(-half_size, -half_size)
	label.label_settings = _get_placeholder_label_settings()
	placeholder.add_child(label)
	return placeholder


## 外部接口：根据 building_type 创建对应节点。
## 通过 BuildingTypeManager.get_category 查询 category，再从 _creators_by_category 取创建函数。
## category 为 GENERIC 或未注册时走占位逻辑。
static func create_building(building_type: String, grid_pos: Vector2i, world_pos: Vector2, node_name: String) -> Node2D:
	var category: BuildingTypeData.Category = BuildingTypeManager.get_category(building_type)
	if _creators_by_category.has(category):
		var creator: Callable = _creators_by_category[category]
		return creator.call(building_type, grid_pos, world_pos, node_name)
	# category 为 GENERIC 或未注册时走占位逻辑
	return _create_placeholder(building_type, grid_pos, world_pos, node_name)
