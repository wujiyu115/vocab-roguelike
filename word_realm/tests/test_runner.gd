# tests/test_runner.gd
extends SceneTree

var _total_passed := 0
var _total_failed := 0
var _total_count := 0
var _all_errors: Array[String] = []

func _initialize():
	print("")
	print("========================================")
	print("  Word Realm Test Suite")
	print("========================================")
	print("")

	# Autoload _ready() is not called in -s mode; initialize manually
	var wb = root.get_node_or_null("WordBank")
	if wb:
		wb.call("load_words")
		wb.call("set_difficulty", 99)

	var suite_paths: Array[String] = [
		"res://tests/test_game_manager.gd",
		"res://tests/test_word_bank.gd",
		"res://tests/test_room_generator.gd",
		"res://tests/test_monster_logic.gd",
		"res://tests/test_click.gd",
		"res://tests/test_room_flow.gd",
	]
	var suites: Array = []
	for path in suite_paths:
		var script: GDScript = load(path)
		if script == null:
			print("ERROR: failed to load %s" % path)
			continue
		suites.append(script.new())

	for suite in suites:
		suite.set_tree_root(root)
		var suite_name: String = suite.get_suite_name()
		print("-- %s --" % suite_name)
		var methods: Array = suite.get_method_list()
		for method_info in methods:
			var method_name: String = method_info.name
			if method_name.begins_with("test_"):
				suite.call(method_name)
		var results: Dictionary = suite.get_results()
		_total_passed += results.passed
		_total_failed += results.failed
		_total_count += results.total
		_all_errors.append_array(results.errors)
		print("")

	print("========================================")
	print("  Results: %d passed, %d failed / %d total" % [_total_passed, _total_failed, _total_count])
	print("========================================")

	if not _all_errors.is_empty():
		print("")
		print("Failed tests:")
		for e in _all_errors:
			print("  - %s" % e)

	print("")
	quit(1 if _total_failed > 0 else 0)
