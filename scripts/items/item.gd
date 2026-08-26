class_name Item
extends RefCounted

## 物品数据模型：数字或操作，是带子上流动的唯一实体。
## - NUM: value 为数字本身（int64，溢出回绕）
## - OP: value 为 OpRegistry 中的操作索引
enum Type { NUM, OP }

var type: Type = Type.NUM
var value: int = 0

static func num(v: int) -> Item:
	var it := Item.new()
	it.type = Item.Type.NUM
	it.value = v
	return it

static func op(idx: int) -> Item:
	var it := Item.new()
	it.type = Item.Type.OP
	it.value = idx
	return it

func is_num() -> bool:
	return type == Item.Type.NUM

func is_op() -> bool:
	return type == Item.Type.OP

func clone() -> Item:
	var it := Item.new()
	it.type = type
	it.value = value
	return it

## 显示文本：数字直接显示数值；操作用注册表名（"@+1" 风格）
func to_display_text() -> String:
	if is_num():
		return str(value)
	return "@" + OpRegistry.op_name(value)

func equals(other: Item) -> bool:
	if other == null:
		return false
	return type == other.type and value == other.value