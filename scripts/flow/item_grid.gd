class_name ItemGrid
extends RefCounted

## 物品格子：cells -> Item 的槽位映射。
## 任意格子都可放置物品（带子持有的物品在带格自身；机器的输入/输出端口格
## 可以停放物品）。每格至多一个物品。
## 注意：ItemSimulator 的移动阶段带"可停靠格"守卫——传送带只会把物品推进到
## 传送带格或机器端口格，空地不接收（背压等待），保证物品不流落到空地上。

var slots: Dictionary[Vector2i, Item] = {}

func has_item(pos: Vector2i) -> bool:
	return slots.has(pos)

func get_item(pos: Vector2i) -> Item:
	return slots.get(pos) as Item

func set_item(pos: Vector2i, item: Item) -> void:
	slots[pos] = item

## 取走并返回该格物品（不存在返回 null）
func take_item(pos: Vector2i) -> Item:
	var item: Item = slots.get(pos) as Item
	if item != null:
		slots.erase(pos)
	return item

func remove_item(pos: Vector2i) -> void:
	slots.erase(pos)

func clear_all() -> void:
	slots.clear()

func count_items() -> int:
	return slots.size()

func is_empty() -> bool:
	return slots.is_empty()

## 获取所有有物品的格子（未排序，仅调试/测试用）
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(slots.keys())
	return cells