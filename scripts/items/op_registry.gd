class_name OpRegistry
extends RefCounted

## 操作注册表（全局静态）：数字物品可携带的操作定义。
## 内置一元操作 + 复合操作（先 A 后 B；当前无产出机器，定义串保留供旧存档/剪贴板恢复）。
## 操作一旦注册即为不可变，apply 是纯函数（value -> value，int64 溢出回绕）。

# 内置操作 id（固定常量，保证存档/组合引用稳定）
const OP_ADD1: int = 0
const OP_SUB1: int = 1
const OP_MUL2: int = 2
const OP_DIV2: int = 3
const OP_NEG: int = 4
const OP_IS_ZERO: int = 5
## 复合操作 id 起始值，避免与内置操作冲突
const FIRST_COMPOSITE_ID: int = 100
## 复合操作定义编码：内置为稳定 key（如 "add1"）；复合为 JSON 数组 ["compose", <defA>, <defB>]，
## 可任意嵌套且无分隔符歧义（存档/剪贴板跨会话恢复用）
const COMPOSE_DEF_TAG: String = "compose"

# id -> { "name": String, "apply": Callable, "desc": String, "def": String }
static var _table: Dictionary = {}
static var _initialized: bool = false
static var _next_composite_id: int = FIRST_COMPOSITE_ID
static var _builtin_ids: Array[int] = []

static func _ensure() -> void:
	if _initialized:
		return
	_initialized = true
	_next_composite_id = FIRST_COMPOSITE_ID
	_builtin_ids.clear()
	# 内置操作集：+1 / -1 / ×2 / ÷2(向零整除) / 取反 / 判零(→1/0)
	_register_builtin(OP_ADD1, "+1", "data + 1", "add1", Callable(OpRegistry, "_apply_add1"))
	_register_builtin(OP_SUB1, "-1", "data - 1", "sub1", Callable(OpRegistry, "_apply_sub1"))
	_register_builtin(OP_MUL2, "×2", "data × 2", "mul2", Callable(OpRegistry, "_apply_mul2"))
	_register_builtin(OP_DIV2, "÷2", "data ÷ 2（向零整除）", "div2", Callable(OpRegistry, "_apply_div2"))
	_register_builtin(OP_NEG, "取反", "-data", "neg", Callable(OpRegistry, "_apply_neg"))
	_register_builtin(OP_IS_ZERO, "判零", "data==0 ? 1 : 0", "iszero", Callable(OpRegistry, "_apply_is_zero"))

static func _register_builtin(id: int, name: String, desc: String, def: String, apply_fn: Callable) -> void:
	_table[id] = {"name": name, "apply": apply_fn, "desc": desc, "def": def}
	_builtin_ids.append(id)

# ---------- 内置操作实现（纯函数，int64 溢出回绕） ----------

static func _apply_add1(v: int) -> int:
	return v + 1

static func _apply_sub1(v: int) -> int:
	return v - 1

static func _apply_mul2(v: int) -> int:
	return v * 2

## Godot int64 整除向零截断（-3/2 = -1）；整除警告是有意行为
@warning_ignore("integer_division")
static func _apply_div2(v: int) -> int:
	return v / 2

static func _apply_neg(v: int) -> int:
	return -v

static func _apply_is_zero(v: int) -> int:
	return 1 if v == 0 else 0

# ---------- 查询 ----------

static func has(id: int) -> bool:
	_ensure()
	return _table.has(id)

static func is_builtin(id: int) -> bool:
	_ensure()
	return id >= 0 and id < FIRST_COMPOSITE_ID and _table.has(id)

## 操作显示名（注意：不能叫 get_name，会与 GDScript 脚本对象原生 get_name() 冲突）
static func op_name(id: int) -> String:
	_ensure()
	if not _table.has(id):
		return "?"
	return _table[id].name

static func get_desc(id: int) -> String:
	_ensure()
	if not _table.has(id):
		return ""
	return _table[id].desc

static func get_builtin_ids() -> Array[int]:
	_ensure()
	var copy: Array[int] = []
	copy.assign(_builtin_ids)
	return copy

## 全部操作（含复合），按 id 升序，供 UI 列表使用
static func get_all_ids() -> Array[int]:
	_ensure()
	var ids: Array[int] = []
	for id: int in _table.keys():
		ids.append(id)
	ids.sort()
	return ids

## 应用操作：未注册操作返回原值（防御性）
static func apply(id: int, value: int) -> int:
	_ensure()
	if not _table.has(id):
		return value
	return (_table[id].apply as Callable).call(value)

## 合成操作：first 先作用，second 后作用，返回新复合操作 id。
## f(x) = second(first(x))。同内容组合幂等（表内已有相同定义则复用）。
static func compose(first_id: int, second_id: int) -> int:
	_ensure()
	var def: String = JSON.stringify(["compose", definition_of(first_id), definition_of(second_id)])
	var existing := id_of_definition(def)
	if existing >= 0:
		return existing
	var id: int = _next_composite_id
	_next_composite_id += 1
	var name: String = "%s→%s" % [op_name(first_id), op_name(second_id)]
	var apply_first: Callable = _table[first_id].apply
	var apply_second: Callable = _table[second_id].apply
	_table[id] = {
		"name": name,
		"desc": "复合操作：先 %s 再 %s" % [op_name(first_id), op_name(second_id)],
		"apply": func(v: int) -> int: return (apply_second as Callable).call((apply_first as Callable).call(v)),
		"def": def,
	}
	return id

# ---------- 定义字符串（存档/剪贴板持久化用，跨会话稳定） ----------

## 操作的稳定定义串：内置为固定 key（add1/…）；复合为 JSON 数组 ["compose", defA, defB]（可嵌套）
static func definition_of(id: int) -> String:
	_ensure()
	if not _table.has(id):
		return ""
	return _table[id].def

## 在表中按定义查找已注册操作（幂等复用），未找到返回 -1
static func id_of_definition(def: String) -> int:
	_ensure()
	if def.is_empty():
		return -1
	for id: int in _table.keys():
		if _table[id].def == def:
			return id
	return -1

## 从定义串恢复操作 id：表内已有则复用；否则按定义重建（内置 key 或 ["compose", …] 链）。
## 未知定义或解析失败返回 -1（调用方应回退到安全默认）。
static func ensure_from_definition(def: String) -> int:
	_ensure()
	if def.is_empty():
		return -1
	var existing := id_of_definition(def)
	if existing >= 0:
		return existing
	if def.begins_with("["):
		# JSON 编码的复合操作（仅对数组形态解析，避免对普通文本抛 JSON 错误）
		var parsed: Variant = JSON.parse_string(def)
		if parsed is Array:
			var arr: Array = parsed
			if arr.size() == 3 and arr[0] == COMPOSE_DEF_TAG:
				var first := ensure_from_definition(str(arr[1]))
				var second := ensure_from_definition(str(arr[2]))
				if first < 0 or second < 0:
					return -1
				return compose(first, second)
		return -1
	# 内置操作定义 key -> 内置 id
	for id: int in _table.keys():
		if is_builtin(id) and _table[id].def == def:
			return id
	return -1

## 测试钩子：清空注册表回到未初始化状态
static func reset() -> void:
	_table.clear()
	_builtin_ids.clear()
	_initialized = false
	_next_composite_id = FIRST_COMPOSITE_ID