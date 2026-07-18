extends RefCounted

## 文件读取结果
class ReadResult extends RefCounted:
	var success: bool = false
	var data: Dictionary = {}
	var error_message: String = ""
	var version_mismatch: bool = false

	static func ok(value: Dictionary) -> ReadResult:
		var result := ReadResult.new()
		result.success = true
		result.data = value
		return result

	static func fail(message: String) -> ReadResult:
		var result := ReadResult.new()
		result.success = false
		result.error_message = message
		return result

	static func version_mismatch_result(value: Dictionary, message: String) -> ReadResult:
		var result := ReadResult.new()
		result.success = true
		result.data = value
		result.error_message = message
		result.version_mismatch = true
		return result

## 读取 JSON 文件，支持版本验证
##  file_path: 文件路径
##  module_name: 模块名称（用于错误消息）
##  expected_version: 期望的版本号（为空则跳过版本检查）
##  on_version_mismatch: 版本不匹配时的回调（接收 data, file_path）
static func read_json_file(
	file_path: String,
	module_name: String,
	expected_version: String = "",
	on_version_mismatch: Callable = Callable()
) -> ReadResult:
	if not FileAccess.file_exists(file_path):
		return ReadResult.fail("%s: 文件不存在: %s" % [module_name, file_path])

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ReadResult.fail("%s: 无法读取文件: %s" % [module_name, file_path])

	var content := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(content)
	if data == null or not data is Dictionary:
		return ReadResult.fail("%s: 文件格式无效，期望 JSON 格式" % module_name)

	var dict: Dictionary = data as Dictionary

	if not dict.has("version"):
		return ReadResult.fail("%s: 文件缺少版本号" % module_name)

	if not expected_version.is_empty() and str(dict.version) != expected_version:
		var warning := "%s: 文件版本不匹配，期望 %s，实际 %s" % [module_name, expected_version, dict.version]
		if on_version_mismatch.is_valid():
			on_version_mismatch.call(dict, file_path)
		return ReadResult.version_mismatch_result(dict, warning)

	return ReadResult.ok(dict)

## 写入 JSON 文件，支持原子写入
##  file_path: 文件路径
##  data: 要写入的数据
##  module_name: 模块名称（用于错误消息）
##  use_atomic: 是否使用原子写入（先写 .tmp 再重命名）
static func write_json_file(
	file_path: String,
	data: Dictionary,
	module_name: String,
	use_atomic: bool = true
) -> bool:
	var dir_path := file_path.get_base_dir()
	var dir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK:
		push_error("%s: 无法创建目录: %s (错误码: %d)" % [module_name, dir_path, dir_err])
		return false

	var write_path := file_path
	if use_atomic:
		write_path = file_path + ".tmp"

	var file := FileAccess.open(write_path, FileAccess.WRITE)
	if not file:
		push_error("%s: 无法写入文件: %s" % [module_name, file_path])
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if use_atomic:
		var rename_err := DirAccess.rename_absolute(write_path, file_path)
		if rename_err != OK:
			push_error("%s: 无法重命名临时文件 (错误码: %d)" % [module_name, rename_err])
			DirAccess.remove_absolute(write_path)
			return false

	return true

## 备份文件
static func backup_file(file_path: String, suffix: String = ".bak") -> bool:
	var backup_path := file_path + suffix
	var err := DirAccess.copy_absolute(file_path, backup_path)
	return err == OK


# ============================================================
# ConfigFile (.cfg) 读写工具
# ============================================================
# 设计说明：单一 .cfg 文件以 section 划分多模块数据（buildings/settings/keybindings）。
# 多模块各自只更新自己负责的 section，写入时先 load 现有文件保留其他 section，
# 再覆盖目标 section，最后原子保存（.tmp -> rename），避免跨模块数据丢失。
# Godot 单线程 + call_deferred/timer 串行化保存调用，故 load-modify-save 不会交错。

## 读取 ConfigFile 中指定 section 的全部键值，返回 Dictionary
##  file_path: .cfg 文件路径
##  section: section 名称
##  module_name: 模块名称（用于错误消息）
##  expected_version: 期望版本号（为空则跳过版本检查；从返回 Dictionary 的 "version" 字段读取）
##  on_version_mismatch: 版本不匹配时的回调（接收 data: Dictionary, file_path: String）
static func read_cfg_section(
	file_path: String,
	section: String,
	module_name: String,
	expected_version: String = "",
	on_version_mismatch: Callable = Callable()
) -> ReadResult:
	if not FileAccess.file_exists(file_path):
		return ReadResult.fail("%s: 文件不存在: %s" % [module_name, file_path])

	var cfg := ConfigFile.new()
	var err := cfg.load(file_path)
	if err != OK:
		return ReadResult.fail("%s: 无法加载配置文件: %s (错误码: %d)" % [module_name, file_path, err])

	if not cfg.has_section(section):
		return ReadResult.fail("%s: 配置文件缺少 section: %s" % [module_name, section])

	var data: Dictionary = {}
	for key: String in cfg.get_section_keys(section):
		data[key] = cfg.get_value(section, key)

	# 版本检查：settings/keybindings/buildings 各自维护 version 字段
	if not expected_version.is_empty():
		var version_val: Variant = data.get("version", "")
		if str(version_val) != expected_version:
			var warning := "%s: section [%s] 版本不匹配，期望 %s，实际 %s" % [
				module_name, section, expected_version, version_val
			]
			if on_version_mismatch.is_valid():
				on_version_mismatch.call(data, file_path)
			return ReadResult.version_mismatch_result(data, warning)

	return ReadResult.ok(data)


## 更新 ConfigFile 中指定 section（保留其他 section）
##  file_path: .cfg 文件路径
##  section: 要覆盖的 section 名称
##  data: 该 section 的完整数据（Dictionary），将完全替换该 section 的现有内容
##  module_name: 模块名称（用于错误消息）
## 原子写入：先写 .tmp 再 rename，避免崩溃导致存档损坏
static func write_cfg_section(
	file_path: String,
	section: String,
	data: Dictionary,
	module_name: String
) -> bool:
	# 确保目录存在
	var dir_path := file_path.get_base_dir()
	var dir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK:
		push_error("%s: 无法创建目录: %s (错误码: %d)" % [module_name, dir_path, dir_err])
		return false

	# 先 load 现有 .cfg，保留其他 section 的数据
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(file_path):
		var load_err := cfg.load(file_path)
		if load_err != OK:
			push_warning("%s: 无法加载现有配置文件 (错误码: %d)，将覆盖整个文件" % [module_name, load_err])
			cfg = ConfigFile.new()

	# 清除目标 section 的旧 key（处理字段被删除的情况）
	# ConfigFile.set_value(section, key, null) 会删除该 key
	if cfg.has_section(section):
		for old_key: String in cfg.get_section_keys(section):
			cfg.set_value(section, old_key, null)

	# 写入新数据
	for key: String in data.keys():
		cfg.set_value(section, key, data[key])

	# 原子保存：先写到 .tmp 再重命名
	var tmp_path := file_path + ".tmp"
	var save_err := cfg.save(tmp_path)
	if save_err != OK:
		push_error("%s: 无法写入文件: %s (错误码: %d)" % [module_name, file_path, save_err])
		return false

	var rename_err := DirAccess.rename_absolute(tmp_path, file_path)
	if rename_err != OK:
		push_error("%s: 无法重命名临时文件 (错误码: %d)" % [module_name, rename_err])
		DirAccess.remove_absolute(tmp_path)
		return false

	return true


## 检查 ConfigFile 中是否存在指定 section（用于启动时判断是否已有任意存档）
static func cfg_has_section(file_path: String, section: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(file_path) != OK:
		return false
	return cfg.has_section(section)


## 将旧 JSON 存档迁移到 .cfg 指定 section（一次性迁移）
##  file_path: 目标 .cfg 路径
##  section: 要写入的 section
##  json_data: 旧 JSON 文件的 Dictionary 内容
##  module_name: 模块名称（用于错误消息）
## 返回是否成功写入该 section
static func migrate_json_to_cfg_section(
	file_path: String,
	section: String,
	json_data: Dictionary,
	module_name: String
) -> bool:
	# 迁移用 write_cfg_section 即可，它会 load -> 更新 -> save
	return write_cfg_section(file_path, section, json_data, module_name)
