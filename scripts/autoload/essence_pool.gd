extends Node

signal essence_changed(new_value: float)

var essence: float = 0.0:
	set(value):
		essence = value
		essence_changed.emit(essence)

func add(amount: float) -> void:
	if amount <= 0.0:
		return
	essence += amount

func subtract(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var actual: float = minf(amount, essence)
	essence -= actual
	return actual

func has(amount: float) -> bool:
	return essence >= amount

func set_value(value: float) -> void:
	essence = maxf(value, 0.0)
