class_name RtsTestCase
extends RefCounted
## Minimal base class for headless tests. Any method named test_* runs.
##
## Ported from the JRPG toolkit's RpgTestCase so the two projects stay the same
## shape: a fix to one can be copied straight across. Dependency-free on
## purpose — swapping the assert helpers is all it would take to move onto GUT
## or gdUnit4 later.
##
## Everything here is explicitly typed because this project runs with
## untyped_declaration and inferred_declaration warnings on.


#region ──────────────────────────────  state  ───────────────────────────────

var failures: PackedStringArray = []
## The running SceneTree, for tests that add nodes or wait for frames.
var tree: SceneTree
## Why the test didn't run (skip()), or "".
var skipped: String = ""
var _current: String = ""

#endregion


#region ────────────────────────  overridable hooks  ─────────────────────────

func before_each() -> void:
	pass


func after_each() -> void:
	pass

#endregion


#region ────────────────────────────  assertions  ────────────────────────────

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true. " + message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected %s, got %s. %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_almost(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected ~%s, got %s. %s" % [expected, actual, message])

#endregion


#region ─────────────────────────────  waiting  ──────────────────────────────

## Sends an input action as if a key was pressed and released, then lets two
## frames pass so the GUI and _unhandled_input see it.
func press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame
	await tree.process_frame


## Waits until `condition` returns true, or gives up after `max_frames` frames
## AND as much time as that many frames take at 60 fps (whichever comes later).
## Frames alone would give up too soon with vsync off, where 60 frames can pass
## before a 0.2 s timer.
func wait_until(condition: Callable, max_frames: int = 300) -> bool:
	var budget: float = max_frames / 60.0
	var elapsed: float = 0.0
	var frames: int = 0
	while frames < max_frames or elapsed < budget:
		if condition.call():
			return true
		await tree.process_frame
		frames += 1
		elapsed += tree.root.get_process_delta_time()
	return condition.call()


## Game time since the tests started (summed frame times: what timers and
## _process count), for measuring how long something took. Wall-clock time
## can disagree when frames run at a fixed rate.
var clock: float:
	get:
		var counter: Node = tree.root.get_node_or_null(^"TestClock")
		return counter.seconds if counter != null else 0.0


## Lets `seconds` of game time pass (at least one frame), however fast the
## frames come: for waits on timers and on anything counting up in _process.
func wait_seconds(seconds: float) -> void:
	var elapsed: float = 0.0
	while true:
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
		if elapsed >= seconds:
			return

#endregion


#region ───────────────────────  failure bookkeeping  ────────────────────────

## Marks the test as not run here (it needs something this build doesn't have).
## Return right after calling it.
func skip(reason: String) -> void:
	skipped = reason


func _fail(text: String) -> void:
	failures.append("%s: %s" % [_current, text])

#endregion
