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
