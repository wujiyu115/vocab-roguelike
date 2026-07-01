# tests/base_test.gd
extends RefCounted

var _passed := 0
var _failed := 0
var _total := 0
var _errors: Array[String] = []
var _suite_name := ""
var _tree_root: Window = null

func get_suite_name() -> String:
	return _suite_name

func set_tree_root(r: Window) -> void:
	_tree_root = r

func get_results() -> Dictionary:
	return {"passed": _passed, "failed": _failed, "total": _total, "errors": _errors.duplicate()}

func assert_eq(actual: Variant, expected: Variant, desc: String) -> void:
	_total += 1
	if actual == expected:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		var msg := "%s: expected %s, got %s" % [desc, str(expected), str(actual)]
		_errors.append("[%s] %s" % [_suite_name, msg])
		print("  FAIL %s" % msg)

func assert_neq(actual: Variant, expected: Variant, desc: String) -> void:
	_total += 1
	if actual != expected:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		var msg := "%s: should not equal %s" % [desc, str(expected)]
		_errors.append("[%s] %s" % [_suite_name, msg])
		print("  FAIL %s" % msg)

func assert_true(value: bool, desc: String) -> void:
	_total += 1
	if value:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		_errors.append("[%s] %s: expected true" % [_suite_name, desc])
		print("  FAIL %s: expected true" % desc)

func assert_false(value: bool, desc: String) -> void:
	_total += 1
	if not value:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		_errors.append("[%s] %s: expected false" % [_suite_name, desc])
		print("  FAIL %s: expected false" % desc)

func assert_gt(actual: float, threshold: float, desc: String) -> void:
	_total += 1
	if actual > threshold:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		var msg := "%s: %s not > %s" % [desc, str(actual), str(threshold)]
		_errors.append("[%s] %s" % [_suite_name, msg])
		print("  FAIL %s" % msg)

func assert_gte(actual: float, threshold: float, desc: String) -> void:
	_total += 1
	if actual >= threshold:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		var msg := "%s: %s not >= %s" % [desc, str(actual), str(threshold)]
		_errors.append("[%s] %s" % [_suite_name, msg])
		print("  FAIL %s" % msg)

func assert_lt(actual: float, threshold: float, desc: String) -> void:
	_total += 1
	if actual < threshold:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		var msg := "%s: %s not < %s" % [desc, str(actual), str(threshold)]
		_errors.append("[%s] %s" % [_suite_name, msg])
		print("  FAIL %s" % msg)

func assert_in_range(value: float, min_val: float, max_val: float, desc: String) -> void:
	_total += 1
	if value >= min_val and value <= max_val:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		var msg := "%s: %s not in [%s, %s]" % [desc, str(value), str(min_val), str(max_val)]
		_errors.append("[%s] %s" % [_suite_name, msg])
		print("  FAIL %s" % msg)

func assert_not_null(value: Variant, desc: String) -> void:
	_total += 1
	if value != null:
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		_errors.append("[%s] %s: value is null" % [_suite_name, desc])
		print("  FAIL %s: value is null" % desc)

func assert_has_key(dict: Dictionary, key: String, desc: String) -> void:
	_total += 1
	if dict.has(key):
		_passed += 1
		print("  pass %s" % desc)
	else:
		_failed += 1
		_errors.append("[%s] %s: missing key '%s'" % [_suite_name, desc, key])
		print("  FAIL %s: missing key '%s'" % [desc, key])
