extends Node

signal essence_threshold_reached(threshold: float, unlocks: Dictionary)

var _thresholds: Array[Dictionary] = []
var _unlocked_thresholds: Dictionary[float, bool] = {}

func _ready() -> void:
	_init_thresholds()
	EssencePool.essence_changed.connect(_on_essence_changed)

func _exit_tree() -> void:
	if EssencePool.essence_changed.is_connected(_on_essence_changed):
		EssencePool.essence_changed.disconnect(_on_essence_changed)

func _init_thresholds() -> void:
	_thresholds = [
		{
			"threshold": 0.0,
			"unlocks": {
				"buildings": ["type_01", "type_02", "type_03", "type_04", "type_07"],
			}
		},
		{
			"threshold": 100.0,
			"unlocks": {
				"description": "\u89e3\u9501\u8f7b\u8d28\u5143\u7d20\u6295\u653e",
			}
		},
		{
			"threshold": 500.0,
			"unlocks": {
				"description": "A \u578b\u5efa\u7b51\u5347\u7ea7\uff08\u591a\u65b9\u5411\u8f93\u51fa\uff09",
			}
		},
		{
			"threshold": 2000.0,
			"unlocks": {
				"description": "\u89e3\u9501\u4e2d\u6027\u5143\u7d20\u6295\u653e",
			}
		},
		{
			"threshold": 5000.0,
			"unlocks": {
				"description": "A \u578b\u5efa\u7b51\u5347\u7ea7\uff08\u66f4\u9ad8\u8f93\u51fa\u901f\u7387\uff09",
			}
		},
		{
			"threshold": 10000.0,
			"unlocks": {
				"description": "B \u578b\u5efa\u7b51\u5347\u7ea7\uff08\u66f4\u5927\u6536\u96c6\u534a\u5f84\uff09",
			}
		},
		{
			"threshold": 50000.0,
			"unlocks": {
				"description": "\u89e3\u9501\u7c98\u6027\u5143\u7d20",
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
			essence_threshold_reached.emit(threshold, entry.unlocks)
			EventBus.essence_threshold_reached.emit(threshold, entry.unlocks)

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
