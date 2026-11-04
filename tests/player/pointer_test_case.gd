class_name PointerTestCase
extends RtsTestCase
## Shared setup for PointerInput tests: the node under the root, a recorder on
## every one of its signals, and helpers that build real InputEvents.
##
## The helpers push events through the viewport rather than calling
## _input()/_unhandled_input() by hand, because the ordering IS the thing under
## test: a gesture must START in _unhandled_input (so the UI gets first refusal)
## and then be OWNED in _input (so a drag across a panel is not cut in half).
## Calling the callbacks directly would skip exactly that, and
## set_input_as_handled() is only legal inside input dispatch anyway.
##
## Pushing an event is synchronous — by the time the helper returns, the signals
## have already fired. Only the long-press timer needs frames to pass, because
## it counts up in _process; those tests await wait_seconds().


#region ────────────────────────────  constants  ─────────────────────────────

## Short so the timer tests are quick. The export's range starts at 0.1.
const LONG_PRESS: float = 0.1

## A move comfortably past any plausible slop radius. Tests about what a drag
## DOES use this, so they cannot fail over where a drag BEGINS; only the two
## tests about the threshold itself go through slop().
const FAR: Vector2 = Vector2(200.0, 0.0)

#endregion


#region ──────────────────────  the pointer under test  ──────────────────────

var pointer: PointerInput
## One entry per emission: [signal name, arg, arg...], in the order they fired.
var emissions: Array[Array] = []

#endregion


#region ─────────────────────────────  fixture  ──────────────────────────────

func before_each() -> void:
	pointer = PointerInput.new()
	pointer.name = "PointerInput"
	pointer.long_press_time = LONG_PRESS
	tree.root.add_child(pointer)
	# _ready() turns _process off, so let it run before any press starts it.
	await tree.process_frame
	pointer.tapped.connect(func(p: Vector2) -> void: _note("tapped", [p]))
	pointer.long_press_started.connect(func(p: Vector2) -> void: _note("long_press_started", [p]))
	pointer.long_press_moved.connect(func(p: Vector2) -> void: _note("long_press_moved", [p]))
	pointer.long_press_ended.connect(func(p: Vector2) -> void: _note("long_press_ended", [p]))
	pointer.drag_started.connect(func(p: Vector2) -> void: _note("drag_started", [p]))
	pointer.dragged.connect(func(p: Vector2, r: Vector2) -> void: _note("dragged", [p, r]))
	pointer.drag_ended.connect(func(p: Vector2) -> void: _note("drag_ended", [p]))
	pointer.pinched.connect(func(f: float, c: Vector2) -> void: _note("pinched", [f, c]))
	pointer.gesture_cancelled.connect(func() -> void: _note("gesture_cancelled", []))


func after_each() -> void:
	if is_instance_valid(pointer):
		tree.root.remove_child(pointer)
		pointer.free()
	await tree.process_frame

#endregion


#region ──────────────────────────  sending events  ──────────────────────────

## A finger going down. `index` is which finger; 0 unless the test wants two.
func touch_down(at: Vector2, index: int = 0) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = true
	_send(event)


func touch_up(at: Vector2, index: int = 0) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = false
	_send(event)


## The OS taking the touch away — a notification shade pulled down, a call
## arriving. Not a release: nothing is committed.
func touch_cancel(at: Vector2, index: int = 0) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = false
	event.canceled = true
	_send(event)


## Deliberately leaves `relative` unset. PointerInput works the step out from
## its own pointer table, so a coalesced or dropped move cannot make the camera
## drift — and the tests prove it by never supplying one.
func touch_move(to: Vector2, index: int = 0) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = to
	_send(event)


func mouse_down(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	_send(_mouse_button(at, button, true))


func mouse_up(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	_send(_mouse_button(at, button, false))


func mouse_move(to: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = to
	_send(event)


func wheel(up: bool, at: Vector2) -> void:
	_send(_mouse_button(at, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true))


## The drag threshold in pixels, worked out the way PointerInput does: a
## fraction of the viewport's shorter side. Asked rather than hardcoded so the
## tests do not go stale when the project's design resolution changes.
func slop() -> float:
	var size: Vector2 = tree.root.get_visible_rect().size
	return minf(size.x, size.y) * pointer.drag_slop_ratio


func _mouse_button(at: Vector2, button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = pressed
	return event


## in_local_coords = true is load-bearing. Without it, push_input() treats the
## position as an OS screen coordinate and divides it by the stretch scale
## before dispatching — on a window twice the design size, every position
## arrives halved, so every position assertion in these files fails by the same
## factor while the ratio-based ones (the pinch factors) still pass.
##
## The game is unaffected: real events come from the OS in screen coordinates
## and Godot converts them on the way in, which is why PointerInput, Control
## rects and the minimap raycast all already agree. It is only this fixture that
## starts out holding viewport coordinates and must say so.
func _send(event: InputEvent) -> void:
	tree.root.push_input(event, true)

#endregion


#region ───────────────────────  reading the gestures  ───────────────────────

## Every signal that fired, in order, by name. Compared against a literal, this
## checks both what happened and what did not.
func fired() -> Array[String]:
	var names: Array[String] = []
	for entry: Array in emissions:
		names.append(entry[0])
	return names


func count(signal_name: String) -> int:
	var total: int = 0
	for entry: Array in emissions:
		if entry[0] == signal_name:
			total += 1
	return total


## The arguments of the first emission of `signal_name`.
##
## When the signal never fired this fails the test here, naming what fired
## instead, and hands back a padded array. Returning a bare [] was worse than
## useless: the caller's `args("drag_started")[0]` then raised an out-of-bounds
## engine error, which aborts the test function and reports a stack trace
## instead of the one thing worth knowing — which signals actually arrived.
func args(signal_name: String) -> Array:
	return _args_of(signal_name, false)


## As args(), but the last emission rather than the first.
func last_args(signal_name: String) -> Array:
	return _args_of(signal_name, true)


func _args_of(signal_name: String, want_last: bool) -> Array:
	var found: Array = []
	var seen: bool = false
	for entry: Array in emissions:
		if entry[0] == signal_name:
			found = entry.slice(1)
			seen = true
			if not want_last:
				break
	if not seen:
		_fail("%s never fired. What did: [%s]" % [signal_name, ", ".join(PackedStringArray(fired()))])
		return [null, null, null]   # the assertions after this still run and still report
	return found


## Forget everything so far, for a test with a setup phase and then the part it
## is actually about.
func clear() -> void:
	emissions.clear()


func _note(signal_name: String, values: Array) -> void:
	var entry: Array = [signal_name]
	entry.append_array(values)
	emissions.append(entry)

#endregion
