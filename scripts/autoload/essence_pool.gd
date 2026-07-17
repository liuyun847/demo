extends Node

signal essence_changed(new_value: float)

## 源质上限，防止数值溢出或异常累积
const MAX_ESSENCE: float = 999999.0

var essence: float = 0.0:
	set(value):
		essence = clampf(value, 0.0, MAX_ESSENCE)
		essence_changed.emit(essence)

var _initialized: bool = false

func _ready() -> void:
	if not _initialized:
		# setter 内部已通过 clampf 约束并 emit essence_changed 信号，无需重复 emit
		essence = maxf(GameConfig.INITIAL_ESSENCE, 0.0)
		_initialized = true

func add(amount: float) -> void:
	if amount <= 0.0:
		return
	essence = clampf(essence + amount, 0.0, MAX_ESSENCE)

func subtract(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var actual: float = minf(amount, essence)
	essence -= actual
	return actual

func has(amount: float) -> bool:
	return essence >= amount

func set_value(value: float) -> void:
	essence = value
