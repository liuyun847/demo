class_name ItemGrid
extends RefCounted

## 物品格子：cells -> Item 的槽位映射。
## 任意格子都可放置物品（带子持有的物品在带格自身；机器的输入/输出端口格
## 可以停放物品，垃圾桶端口格除外——其端口格不可停靠；垃圾桶本体格可停靠
## （传送带推入销毁），不接受旁格吸取、接受贴脸投递）。
## 每格至多一个物品。
## 注意：ItemSimulator 的移动阶段带"可停靠格"守卫——传送带只会把物品推进到
## 传送带格或机器端口格，空地不接收（背压等待），保证物品不流落到空地上。
## 另含"面槽"（edge_slots）：0 格贴脸机器直传时，物品压在生产者某一面的共享边
## 上（键=生产者本体格，值={item, front: Vector2i}），不属于任何网格格，故与 slots 无冲突。

var slots: Dictionary[Vector2i, Item] = {}
## 面槽：键=生产者机器格 P；值={"item": Item, "front": Vector2i}（front=物品压着的
## 面方向，即生产者→消费者的格偏移）。槽满 = 生产者背压等待；由消费机器在机器相位读取/清除。
var edge_slots: Dictionary[Vector2i, Dictionary] = {}

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
	edge_slots.clear()

func count_items() -> int:
	return slots.size()

## 网格槽是否为空（不含面槽物品；物品流判定/清理使用）
func is_empty() -> bool:
	return slots.is_empty()

# ---------- 面槽（0 格贴脸直传的共享边暂存） ----------

func has_edge(cell: Vector2i) -> bool:
	return edge_slots.has(cell)

func get_edge(cell: Vector2i) -> Dictionary:
	return edge_slots.get(cell, {})

## 写入面槽：{item, front}。front=物品压着的面方向（生产者→消费者的偏移）。
## 调用方须先确认槽空（has_edge 守卫）再写入。
func set_edge(cell: Vector2i, item: Item, front: Vector2i) -> void:
	edge_slots[cell] = {"item": item, "front": front}

## 取走并返回该格面槽物品（不存在返回 null）
func take_edge(cell: Vector2i) -> Item:
	var slot: Dictionary = edge_slots.get(cell, {})
	if slot.is_empty():
		return null
	edge_slots.erase(cell)
	return slot.get("item") as Item

func remove_edge(cell: Vector2i) -> void:
	edge_slots.erase(cell)

func count_edge_items() -> int:
	return edge_slots.size()

## 获取所有有物品的格子（未排序，仅调试/测试用）
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(slots.keys())
	return cells