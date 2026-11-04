extends SceneTree
## Command-line test runner. From the project folder:
##   godot --headless --import            (first time only: builds the class list)
##   godot --headless -s res://tests/run_tests.gd
## Exits with code 0 when every test passes, 1 otherwise, so it works in CI.
## Options after "--":
##   --only=player     only test files whose path contains "player"
##   --test=pinch      only test methods whose name contains "pinch"
##   --verbose         print each test's name before it runs (finds a hang)
## In the editor, open tests/run_tests.tscn and press F6 instead.


func _initialize() -> void:
	# During _initialize the root window isn't in the tree yet, so nodes added
	# now never get _ready() or @onready. One frame later everything is live.
	await process_frame
	var only: String = ""
	var verbose: bool = false
	var test_filter: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--test="):
			test_filter = arg.trim_prefix("--test=")
		elif arg == "--verbose":
			verbose = true
	var failed: int = await RtsTestRunner.run_all(self, only, verbose, test_filter)
	# A moment for the last test's queued frees before quitting, or they are
	# reported leaked.
	await process_frame
	await create_timer(0.25, true, false, true).timeout
	quit(0 if failed == 0 else 1)
