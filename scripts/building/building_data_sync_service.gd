class_name BuildingDataSyncService
extends RefCounted

## 将节点状态同步到 BuildingData，必要时根据 restore_data 反向写入节点。
## 物品流建筑：传送带/机器把 direction/op_choice/filter/splitter_phase 双向同步。
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
		if restore_data.has("filter_kind") or restore_data.has("filter_cmp") or restore_data.has("filter_value"):
			if restore_data.has("filter_kind"):
				data.filter_kind = str(restore_data["filter_kind"])
			if restore_data.has("filter_cmp"):
				data.filter_cmp = str(restore_data["filter_cmp"])
			if restore_data.has("filter_value"):
				data.filter_value = int(restore_data["filter_value"])
			if data.filter_kind == "op" and (restore_data.has("filter_op_def") or restore_data.has("filter_value")):
				data.filter_value = _restore_op_id(restore_data, "filter_value", "filter_op_def")
			_apply_filter(node, data.filter_kind, data.filter_cmp, data.filter_value)
		if restore_data.has("splitter_phase"):
			data.splitter_phase = int(restore_data["splitter_phase"])
			_apply_splitter_phase(node, data.splitter_phase)
		return
	# 节点 -> data
	data.direction = _get_direction(node)
	if node is MachineNode:
		var machine := node as MachineNode
		data.op_choice = machine.op_choice
		data.filter_kind = machine.filter_kind
		data.filter_cmp = machine.filter_cmp
		data.filter_value = machine.filter_value
		data.splitter_phase = machine.splitter_phase


static func _apply_direction(node: Node, dir: int) -> void:
	if node.has_method("set_direction"):
		node.set_direction(dir)

static func _apply_op_choice(node: Node, op_id: int) -> void:
	if node.has_method("set_op_choice"):
		node.set_op_choice(op_id)

static func _apply_filter(node: Node, kind: String, cmp: String, value: int) -> void:
	if node.has_method("set_filter"):
		node.set_filter(kind, cmp, value)

static func _apply_splitter_phase(node: Node, phase: int) -> void:
	if node.has_method("set_splitter_phase"):
		node.set_splitter_phase(phase)

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


## 从存档/剪贴板条目提取 restore_data（物品流字段）
static func entry_to_restore_data(entry: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for key: String in ["direction", "op_choice", "op_def", "filter_kind", "filter_cmp", "filter_value", "filter_op_def", "splitter_phase"]:
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
		if data.filter_kind != "num" or data.filter_cmp != "gt" or data.filter_value != 0:
			entry["filter_kind"] = data.filter_kind
			entry["filter_cmp"] = data.filter_cmp
			entry["filter_value"] = data.filter_value
			if data.filter_kind == "op" and OpRegistry.has(data.filter_value):
				entry["filter_op_def"] = OpRegistry.definition_of(data.filter_value)
		if data.splitter_phase != 0:
			entry["splitter_phase"] = data.splitter_phase
	return entry