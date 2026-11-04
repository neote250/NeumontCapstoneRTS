extends Node
## Adds up frame times while the tests run (the runner puts one under the root):
## the game time that timers and _process count, for tests that measure how long
## something took (RtsTestCase.clock).
##
## It also says where a run stopped, two ways:
## - a test that keeps running for STUCK_AFTER seconds gets a "STILL RUNNING"
##   line naming it (a test waiting for something that never happens);
## - when the game stops processing for PAUSED_AFTER_MSEC, a watcher on its own
##   thread prints a "PAUSED" line naming the test, and why: if the window still
##   draws, the game was suspended (the pause button on the editor's game
##   toolbar); if it doesn't, the debugger stopped on an error (Debugger >
##   Stack Trace shows which line).
##
## Ported from the JRPG toolkit unchanged apart from explicit types.


#region ────────────────────────────  constants  ─────────────────────────────

const STUCK_AFTER: float = 60.0
const PAUSED_AFTER_MSEC: int = 10000

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

var seconds: float = 0.0
var _test: String = ""
var _test_started: float = 0.0
var _warned: bool = false

# Shared with the watcher thread, so read and written under _lock.
var _lock: Mutex = Mutex.new()
var _last_frame_msec: int = 0
var _stop: bool = false
var _watcher: Thread

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_frame_msec = Time.get_ticks_msec()
	_watcher = Thread.new()
	_watcher.start(_watch)


func _exit_tree() -> void:
	stop_watching()


func _process(delta: float) -> void:
	seconds += delta
	_lock.lock()
	_last_frame_msec = Time.get_ticks_msec()
	_lock.unlock()
	var running: float = float(Time.get_ticks_msec()) / 1000.0 - _test_started
	if not _test.is_empty() and not _warned and running > STUCK_AFTER:
		_warned = true
		print("  STILL RUNNING after %d s: %s (it may be stuck)" % [int(running), _test])

#endregion


#region ─────────────────────────────  counting  ─────────────────────────────

## The runner calls this as each test starts.
func started(test_name: String) -> void:
	_lock.lock()
	_test = test_name
	_lock.unlock()
	_test_started = float(Time.get_ticks_msec()) / 1000.0
	_warned = false

#endregion


#region ────────────────────────  the watcher thread  ────────────────────────

## Stops the watcher thread and waits for it (call before freeing this).
func stop_watching() -> void:
	if _watcher == null:
		return
	_lock.lock()
	_stop = true
	_lock.unlock()
	_watcher.wait_to_finish()
	_watcher = null


func _watch() -> void:
	var said: bool = false
	var drawn_at_quiet: int = 0
	while true:
		OS.delay_msec(250)
		_lock.lock()
		var stop: bool = _stop
		var quiet: int = Time.get_ticks_msec() - _last_frame_msec
		var test: String = _test
		_lock.unlock()
		if stop:
			return
		if quiet < 1000:
			if said:
				print("  ...running again.")
			said = false
			drawn_at_quiet = Engine.get_frames_drawn()
		elif quiet >= PAUSED_AFTER_MSEC and not said:
			said = true
			var where: String = test if not test.is_empty() else "startup"
			# Suspended, the engine keeps drawing frames but skips _process;
			# stopped in the debugger, nothing runs on the main thread at all.
			if Engine.get_frames_drawn() > drawn_at_quiet + 2:
				print("  PAUSED during %s: the game was suspended (the pause button on the game toolbar). Press it again to carry on." % where)
			else:
				print("  PAUSED during %s: the debugger stopped here, usually on an error. Open Debugger > Stack Trace to see the message and line, then press Continue." % where)

#endregion
