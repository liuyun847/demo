extends Node

var _thresholds: Array[Dictionary] = []
var _unlocked_thresholds: Dictionary[float, bool] = {}

func _ready() -> void:
	_init_thresholds()
	EssencePool.essence_changed.connect(_on_essence_changed)
	_on_essence_changed(EssencePool.essence)

func _exit_tree() -> void:
	if EssencePool.essence_changed.is_connected(_on_essence_changed):
		EssencePool.essence_changed.disconnect(_on_essence_changed)

func _init_thresholds() -> void:
	_thresholds = [
		{
			"threshold": 0.0,
			"unlocks": {
				"buildings": ["type_02", "type_03", "type_04", "type_07"],
			}
		},
		{
			"threshold": 100.0,
			"unlocks": {
				"description": "解锁轻质元素投放",
			}
		},
		{
			"threshold": 500.0,
			"unlocks": {
				"description": "A 型建筑升级（多方向输出）",
			}
		},
		{
			"threshold": 2000.0,
			"unlocks": {
				"description": "解锁中性元素投放",
			}
		},
		{
			"threshold": 5000.0,
			"unlocks": {
				"description": "A 型建筑升级（更高输出速率）",
			}
		},
		{
			"threshold": 10000.0,
			"unlocks": {
				"description": "B 型建筑升级（更大收集半径）",
			}
		},
		{
			"threshold": 50000.0,
			"unlocks": {
				"description": "解锁粘性元素",
			}
		},
	]

func _on_essence_changed(value: float) -> void:
	for entry: Dictionary in _thresholds:
		var threshold: float = entry.threshold
		if _unlocked_thresholds.has(threshold):
			continue
		if value >= threshold:
			_unlocked_thresholds[threshold] = true
			# 深拷贝 unlocks，防止接收方修改影响原始数据
			EventBus.essence_threshold_reached.emit(threshold, (entry.unlocks as Dictionary).duplicate(true))

func get_unlocked_building_types() -> Array:
	var unlocked: Array = []
	for entry: Dictionary in _thresholds:
		var threshold: float = entry.threshold
		if not _unlocked_thresholds.has(threshold):
			continue
		if entry.unlocks.has("buildings"):
			for btype: String in entry.unlocks.buildings:
				if not btype in unlocked:
					unlocked.append(btype)
	return unlocked

func is_building_unlocked(building_type: String) -> bool:
	var unlocked: Array = get_unlocked_building_types()
	return building_type in unlocked
