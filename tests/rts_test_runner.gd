class_name RtsTestRunner
extends RefCounted
## Finds every tests/**/test_*.gd file and runs each test_* method.
## Shared by the command-line runner (run_tests.gd) and the editor scene
## (run_tests.tscn), so both run exactly the same tests.
##
## Ported from the JRPG toolkit's RpgTestRunner — kept the same so fixes travel
## between the two projects.


#region ────────────────────────────  constants  ─────────────────────────────

const TEST_DIR: String = "res://tests"

#endregion


#region ──────────────────────────  error catching  ──────────────────────────

## Catches runtime script errors (null access, type mismatch...). Without it,
## Godot aborts the failing function, prints the error, and the test would still
## count as passed. push_error() from game code is a different error type and
## does not fail tests: this project uses it deliberately (set_active_squad out
## of range, the current_squad_index setter), and some tests check for it.
class ScriptErrorCatcher extends Logger:
	var errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			errors.append("%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file.get_file(), line])

	func _log_message(_message: String, _error: bool) -> void:
		pass

#endregion


#region ─────────────────────────────  running  ──────────────────────────────

## Runs every test, printing failures as it goes. Returns the failure count.
## A coroutine: tests may await (anything waiting for frames does), so callers
## must `await RtsTestRunner.run_all(tree)`.
## `only`: run just the files whose path contains it. `verbose`: print each
## test's name as it starts. `test_filter`: run just the test methods whose
## name contains it.
static func run_all(tree: SceneTree, only: String = "", verbose: bool = false, test_filter: String = "") -> int:
	var passed: int = 0
	var failed: int = 0
	var skipped: Dictionary = {}  # reason -> how many
	var catcher: ScriptErrorCatcher = ScriptErrorCatcher.new()
	OS.add_logger(catcher)
	# The tests' game clock (RtsTestCase.clock): summed frame times.
	var counter: Node = load("res://tests/test_clock.gd").new()
	counter.name = "TestClock"
	tree.root.add_child(counter)
	for path: String in _find_tests(TEST_DIR):
		if not only.is_empty() and not path.contains(only):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("  LOAD FAILED  ", path)
			failed += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_") or (not test_filter.is_empty() and not method_name.contains(test_filter)):
				continue
			var test: RtsTestCase = script.new()
			test._current = "%s::%s" % [path.get_file(), method_name]
			if verbose:
				print("  ...  ", test._current)
			counter.call(&"started", test._current)
			test.tree = tree
			catcher.errors.clear()
			@warning_ignore("redundant_await")  # (an override may wait for frames)
			await test.before_each()
			# await works for plain methods too: it just returns right away.
			await test.call(method_name)
			@warning_ignore("redundant_await")  # (an override may wait for frames)
			await test.after_each()  # may wait for frames (freeing nodes)
			for error: String in catcher.errors:
				test.failures.append("%s: script error: %s" % [test._current, error])
			if test.failures.is_empty() and not test.skipped.is_empty():
				skipped[test.skipped] = skipped.get(test.skipped, 0) + 1
			elif test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f: String in test.failures:
					print("  FAIL  ", f)
	OS.remove_logger(catcher)
	var summary: String = "%d passed, %d failed" % [passed, failed]
	for reason: String in skipped:
		summary += "\n%d skipped (%s)" % [skipped[reason], reason]
	print("\n%s" % summary)
	tree.root.set_meta(&"rts_test_summary", summary)  # (the editor runner shows it in its window)
	if is_instance_valid(counter):
		# Stop its watcher thread first: an object can't be freed while a thread
		# is still running one of its methods.
		counter.call(&"stop_watching")
		counter.free()
	return failed

#endregion


#region ────────────────────────────  discovery  ─────────────────────────────

static func _find_tests(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_find_tests(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found

#endregion
