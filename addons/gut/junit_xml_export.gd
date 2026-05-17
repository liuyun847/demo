## Exposes functionality to export results of a test run in JUnit XML format.
##
## This class exposes two methods for exporting GUT test results to XML.
## One returns a string representing the XML, and the other writes it to
## a file.

var _strutils := GutStringUtils.new()
var _exporter = GutUtils.ResultExporter.new()


func _wrap_cdata(content) -> String:
	return "<![CDATA[" + str(content) + "]]>"


func _add_attr(name, value) -> String:
	return str(name, '="', value, '" ')


func _export_test_result(test: Dictionary) -> String:
	var to_return := ''

	# Right now the pending and failure messages won't fit in the message
	# attribute because they can span multiple lines and need to be escaped.
	if(test.status == 'pending'):
		var skip_tag := str("<skipped message=\"pending\">", _wrap_cdata(test.pending[0]), "</skipped>")
		to_return += skip_tag
	elif(test.status == 'fail'):
		var fail_tag := str("<failure message=\"failed\">", _wrap_cdata(test.failing[0]), "</failure>")
		to_return += fail_tag

	return to_return


func _export_tests(script_result: Dictionary, classname: String) -> Array:
	var to_return := ""
	var fail_count := 0
	var skip_count := 0
	var test_count := 0

	for test_name: String in script_result.keys():
		var test: Dictionary = script_result[test_name]
		if test.status == 'pass':
			continue
		test_count += 1
		var assert_count = test.passing.size() + test.failing.size()
		to_return += "<testcase "
		to_return += _add_attr("name", test_name)
		to_return += _add_attr("assertions", assert_count)
		to_return += _add_attr("status", test.status)
		to_return += _add_attr("classname", classname.replace("res://", ""))
		to_return += _add_attr("time", test.time_taken)
		to_return += ">\n"

		to_return += _export_test_result(test)

		to_return += "</testcase>\n"

		if test.status == 'fail':
			fail_count += 1
		elif test.status == 'pending':
			skip_count += 1

	return [to_return, fail_count, test_count, skip_count]


func _sum_test_time(script_result: Dictionary) -> float:
	var to_return := 0.0

	for test: Dictionary in script_result.values():
		to_return += test.time_taken

	return to_return


func _export_scripts(exp_results: Dictionary) -> Array:
	var to_return := ""
	var total_fail := 0
	var total_test := 0
	var total_skip := 0
	for script_path: String in exp_results.test_scripts.scripts.keys():
		var s: Dictionary = exp_results.test_scripts.scripts[script_path]
		var test_result: Array = _export_tests(s.tests, script_path)
		var tests_xml: String = test_result[0]
		var fail_cnt: int = test_result[1]
		var test_cnt: int = test_result[2]
		var skip_cnt: int = test_result[3]
		if test_cnt == 0:
			continue
		to_return += "<testsuite "
		to_return += _add_attr("name", script_path.replace("res://", ""))
		to_return += _add_attr("tests", test_cnt)
		to_return += _add_attr("failures", fail_cnt)
		to_return += _add_attr("skipped", skip_cnt)
		to_return += _add_attr("time", _sum_test_time(s.tests))
		to_return += ">\n"

		to_return += _strutils.indent_text(tests_xml, 1, "    ")

		to_return += "</testsuite>\n"
		total_fail += fail_cnt
		total_test += test_cnt
		total_skip += skip_cnt

	return [to_return, total_fail, total_test, total_skip]


## Takes in an instance of [GutMain] and returns a string of XML representing
## the results of the run.
func get_results_xml(gut: GutMain) -> String:
	var exp_results: Dictionary = _exporter.get_results_dictionary(gut)
	var scripts_result: Array = _export_scripts(exp_results)
	var scripts_xml: String = scripts_result[0]
	var fail_count: int = scripts_result[1]
	var test_count: int = scripts_result[2]
	var skip_count: int = scripts_result[3]
	var to_return := '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
	to_return += '<testsuites '
	to_return += _add_attr("name", 'GutTests')
	to_return += _add_attr("failures", fail_count)
	to_return += _add_attr('tests', test_count)
	to_return += _add_attr('skipped', skip_count)
	# allpass attribute: true when no failures and no pending tests
	if fail_count == 0 and skip_count == 0:
		to_return += _add_attr('allpass', 'true')
	to_return += ">\n"

	to_return += _strutils.indent_text(scripts_xml, 1, "  ")

	to_return += '</testsuites>'
	return to_return


## Takes in an instance of GutMain and writes test results to an XML file
## specified by [param path]. Return value is an error code forwarded from
## the call to FileAccess.open to write to [param path].
func write_file(gut: GutMain, path: String) -> int:
	var xml := get_results_xml(gut)

	var f_result: int = GutUtils.write_file(path, xml)
	if(f_result != OK):
		var msg := str("Error:  ", f_result, ".  Could not create export file ", path)
		GutUtils.get_logger().error(msg)

	return f_result
