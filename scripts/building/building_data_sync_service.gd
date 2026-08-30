class_name BuildingDataSyncService
extends RefCounted

## 将节点状态同步到 BuildingData，必要时根据 restore_data 反向写入节点。
## 物品流建筑：传送带/机器把 direction/op_choice/splitter_phase/splitter_in_phase/splitter_filters 双向同步。
## 另有 entry <-> restore_data 助手，供撤销/剪贴板/存档统一搬运物品流字段。

static func sync_from_node(data: BuildingData, node: Node, restore_data: Dictionary = {}) -> void:
	if data == null:
		push_warning("BuildingDataSyncService.sync_from_node: data 为 null，跳过同步")
		return
	if node == null:
		push_warning("BuildingDataSyncService.sync_from_node: node 为 null，跳过同步")
		return
	if not (node is BeltNode or node is MachineNode):
		return
	# 无 restore_data = 节点 -> data；有 restore_data = 反写两者
	if not restore_data.is_empty():
		if restore_data.has("direction"):
			data.direction = int(restore_data["direction"])
			_apply_direction(node, data.direction)
		if restore_data.has("op_choice") or restore_data.has("op_def"):
			# 优先按定义串恢复（跨会话稳定）；无定义时退回旧数字 id
			data.op_choice = _restore_op_id(restore_data, "op_choice", "op_def")
			_apply_op_choice(node, data.op_choice)
		if restore_data.has("splitter_filters"):
			data.splitter_filters = _restore_filters(restore_data["splitter_filters"])
			_apply_splitter_filters(node, data.splitter_filters)
		if restore_data.has("splitter_phase"):
			data.splitter_phase = int(restore_data["splitter_phase"])
			_apply_splitter_phase(node, data.splitter_phase)
		if restore_data.has("splitter_in_phase"):
			data.splitter_in_phase = int(restore_data["splitter_in_phase"])
			_apply_splitter_in_phase(node, data.splitter_in_phase)
		return
	# 节点 -> data
	data.direction = _get_direction(node)
	if node is MachineNode:
		var machine := node as MachineNode
		data.op_choice = machine.op_choice
		data.splitter_phase = machine.splitter_phase
		data.splitter_in_phase = machine.splitter_in_phase
		data.splitter_filters = machine.splitter_filters.duplicate(true)


static func _apply_direction(node: Node, dir: int) -> void:
	if node.has_method("set_direction"):
		node.set_direction(dir)

static func _apply_op_choice(node: Node, op_id: int) -> void:
	if node.has_method("set_op_choice"):
		node.set_op_choice(op_id)

static func _apply_splitter_filters(node: Node, filters: Array) -> void:
	if node.has_method("set_splitter_filters"):
		node.set_splitter_filters(filters)


## 从存档/剪贴板恢复按方向过滤条件：裁剪/清洗到 4 方向，op 条件优先按定义串重建 id
static func _restore_filters(raw: Variant) -> Array:
	var result: Array = [{}, {}, {}, {}]
	if not (raw is Array):
		return result
	var arr: Array = raw
	for dir in range(mini(arr.size(), 4)):
		var cond: Variant = arr[dir]
		if not (cond is Dictionary):
			continue  # 非字典条目 = 无条件
		var clean := {}
		var kind := str((cond as Dictionary).get("kind", ""))
		if kind == "op":
			clean["kind"] = "op"
			var op_id := -1
			if (cond as Dictionary).has("op_def"):
				var restored := OpRegistry.ensure_from_definition(str((cond as Dictionary)["op_def"]))
				if restored >= 0:
					op_id = restored
			if op_id < 0 and (cond as Dictionary).has("value"):
				op_id = int((cond as Dictionary)["value"])  # 退回旧数字 id（同会话内有效）
			if op_id >= 0 and OpRegistry.has(op_id):
				clean["value"] = op_id
			else:
				continue  # 操作 id 无法恢复 = 该方向视为无条件
		elif kind == "num":
			clean["kind"] = "num"
			clean["cmp"] = str((cond as Dictionary).get("cmp", "gt"))
			clean["value"] = int((cond as Dictionary).get("value", 0))
		else:
			continue  # 未知 kind = 无条件
		result[dir] = clean
	return result

static func _apply_splitter_phase(node: Node, phase: int) -> void:
	if node.has_method("set_splitter_phase"):
		node.set_splitter_phase(phase)

static func _apply_splitter_in_phase(node: Node, phase: int) -> void:
	if node.has_method("set_splitter_in_phase"):
		node.set_splitter_in_phase(phase)

static func _get_direction(node: Node) -> int:
	var dir: Variant = node.get("direction")
	if dir is int:
		return dir
	return 0

## 从 restore_data 恢复操作 id：优先定义串（跨会话稳定），退回数字 id
static func _restore_op_id(restore_data: Dictionary, id_key: String, def_key: String) -> int:
	if restore_data.has(def_key):
		var restored := OpRegistry.ensure_from_definition(str(restore_data[def_key]))
		if restored >= 0:
			return restored
	if restore_data.has(id_key):
		return int(restore_data[id_key])
	return -1


## 任一方向设了条件（非空字典）即视为"过滤已配置"
static func _has_any_filter(filters: Array) -> bool:
	for cond: Variant in filters:
		if cond is Dictionary and not (cond as Dictionary).is_empty():
			return true
	return false


## 从存档/剪贴板条目提取 restore_data（物品流字段）
static func entry_to_restore_data(entry: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for key: String in ["direction", "op_choice", "op_def", "splitter_phase", "splitter_in_phase", "splitter_filters"]:
		if entry.has(key):
			d[key] = entry[key]
	return d

## 从 BuildingData 提取条目字段（撤销/剪贴板/存档共用；默认配置省略，保持条目精简）
static func data_to_entry(data: BuildingData) -> Dictionary:
	var entry := {"type": data.building_type}
	if MachineSpec.is_belt(data.building_type) or MachineSpec.is_machine(data.building_type):
		entry["direction"] = data.direction
		if data.op_choice >= 0:
			entry["op_choice"] = data.op_choice
			entry["op_def"] = OpRegistry.definition_of(data.op_choice)
		if _has_any_filter(data.splitter_filters):
			# 只落盘有条件的方向（保持条目精简）；op 条件附带定义串（复合操作跨会话稳定）
			var filters: Array = [{}, {}, {}, {}]
			for dir in range(mini(data.splitter_filters.size(), 4)):
				var cond: Variant = data.splitter_filters[dir]
				if cond is Dictionary and not (cond as Dictionary).is_empty():
					var saved: Dictionary = (cond as Dictionary).duplicate(true)
					if saved.get("kind", "") == "op" and OpRegistry.has(int(saved.get("value", -1))):
						saved["op_def"] = OpRegistry.definition_of(int(saved["value"]))
					filters[dir] = saved
			entry["splitter_filters"] = filters
		if data.splitter_phase != 0:
			entry["splitter_phase"] = data.splitter_phase
		if data.splitter_in_phase != 0:
			entry["splitter_in_phase"] = data.splitter_in_phase
	return entry