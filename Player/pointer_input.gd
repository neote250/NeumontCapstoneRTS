extends Node
class_name PointerInput
## Turns raw pointer events — fingers on a phone, a mouse in the editor — into
## the handful of gestures this game has an opinion about, in screen
## coordinates.
##
## This is the only place in the project that reads a pointer InputEvent.
## Everything downstream listens to a signal, so nothing else has to know
## whether a thumb or a mouse produced it.
##
## Gestures START in _unhandled_input, so a tap the UI wanted — a build button,
## a squad row — is consumed before it gets here and never becomes a world
## order. Once a gesture owns a pointer the node switches to _input and marks
## events handled, so a drag that crosses a panel is not cut in half by it.


#region ─────────────────────────────  signals  ──────────────────────────────

## Pressed and released without travelling. The move / attack / gather order.
signal tapped(position: Vector2)

## Held still past long_press_time, or right mouse down. The wheel opens here.
signal long_press_started(position: Vector2)
## The pointer moved while the wheel is open. Never emitted before it opens.
signal long_press_moved(position: Vector2)
## Released. Whoever opened on long_press_started commits here.
signal long_press_ended(position: Vector2)

## Travelled past the slop radius before long_press_time elapsed.
signal drag_started(position: Vector2)
signal dragged(position: Vector2, relative: Vector2)
signal drag_ended(position: Vector2)

## Two pointers changing separation, or the mouse wheel. Above 1.0 is fingers
## moving apart. Emitted per step, not as a total — listeners multiply.
signal pinched(factor: float, center: Vector2)

## The gesture was abandoned rather than finished: focus lost, the OS took the
## touch, or a second finger arrived. Anything a start put on screen must come
## back off here, because no end signal is coming.
signal gesture_cancelled()

#endregion


#region ────────────────────────────  constants  ─────────────────────────────

## The id the mouse enters the pointer table under, so one table serves both
## devices. Real touch indices start at 0.
const MOUSE_POINTER: int = -1

enum Phase {
	IDLE,        ## Nothing pressed. _input passes every event straight through.
	PENDING,     ## Pressed, not yet far enough to drag or long enough to hold.
	DRAG,
	LONG_PRESS,
	PINCH,
}

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Timing")
## How long a still press waits before it becomes a long press.
@export_range(0.1, 1.0, 0.05) var long_press_time: float = 0.35

@export_group("Slop")
## How far a press may travel and still be a tap, as a fraction of the
## viewport's shorter side. A fraction rather than pixels: the same 16 px is a
## comfortable wobble on a phone and a mis-click on a desktop monitor.
@export_range(0.005, 0.1, 0.001) var drag_slop_ratio: float = 0.02

@export_group("Pinch")
## Ignore changes smaller than this, so two fingers resting is not a zoom.
@export_range(0.0, 0.2, 0.01) var pinch_deadzone: float = 0.02
## One mouse wheel notch as a pinch factor. The desktop stand-in for a pinch.
@export_range(1.0, 2.0, 0.01) var wheel_step: float = 1.1
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

var _phase: Phase = Phase.IDLE
## Pointer id → last known screen position. The mouse is MOUSE_POINTER.
var _pointers: Dictionary[int, Vector2] = {}
## Which pointer owns the current one-pointer gesture. -1 when none does.
var _primary: int = -1
var _press_position: Vector2 = Vector2.ZERO
var _held_for: float = 0.0
## Separation between the two pointers at the last pinch report.
var _pinch_distance: float = 0.0

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	# Only runs between a press and the moment it resolves — see _process.
	set_process(false)


## Gestures begin here and nowhere else. An event the UI wanted was consumed
## before this callback, which is the entire reason the start lives in
## _unhandled_input rather than _input.
func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.IDLE:
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_begin_press(touch.index, touch.position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		_begin_mouse(event as InputEventMouseButton)


## A gesture is in flight, so every pointer event belongs to it. Marked handled
## so the GUI cannot take a drag away halfway through by being under the finger.
func _input(event: InputEvent) -> void:
	if _phase == Phase.IDLE:
		return   # not ours — the UI gets first refusal, then _unhandled_input

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.canceled:
			_cancel()
		elif touch.pressed:
			_add_pointer(touch.index, touch.position)
		else:
			_end_press(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_move_pointer(drag.index, drag.position)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_move_pointer(MOUSE_POINTER, motion.position)
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.pressed or not _is_gesture_button(click.button_index):
			return
		_end_press(MOUSE_POINTER, click.position)
	else:
		return

	get_viewport().set_input_as_handled()


## Counts out a still press. Turned off the moment the press resolves into
## something, so an idle game is not running a callback to watch nothing.
func _process(delta: float) -> void:
	_held_for += delta
	if _held_for >= long_press_time:
		_enter_long_press()


## The window lost focus mid-gesture. Without this _phase stays non-IDLE and
## _input swallows every pointer event from here on — the game would look
## frozen to the pointer while running perfectly.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _phase != Phase.IDLE:
		_cancel()

#endregion


#region ────────────────────────  starting a gesture  ────────────────────────

func _begin_press(id: int, position: Vector2) -> void:
	_pointers[id] = position
	_primary = id
	_press_position = position
	_held_for = 0.0
	_phase = Phase.PENDING
	set_process(true)


## The mouse enters the same table as a finger, with two shortcuts a finger
## does not have: right button is the wheel without the wait, and the scroll
## wheel is a pinch without the second finger.
func _begin_mouse(click: InputEventMouseButton) -> void:
	if not click.pressed:
		return
	match click.button_index:
		MOUSE_BUTTON_LEFT:
			_begin_press(MOUSE_POINTER, click.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			_begin_press(MOUSE_POINTER, click.position)
			_enter_long_press()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_UP:
			pinched.emit(wheel_step, click.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			pinched.emit(1.0 / wheel_step, click.position)


func _enter_long_press() -> void:
	_phase = Phase.LONG_PRESS
	set_process(false)
	long_press_started.emit(_press_position)


## A second pointer arrived while one was already down. Two pointers is a pinch
## and nothing else — whatever the first was doing is abandoned, because the
## camera should not still be panning halfway through a zoom.
func _add_pointer(id: int, position: Vector2) -> void:
	_pointers[id] = position
	if _pointers.size() != 2:
		return
	if _phase == Phase.DRAG:
		drag_ended.emit(_pointers[_primary])
	elif _phase == Phase.LONG_PRESS:
		gesture_cancelled.emit()
	_phase = Phase.PINCH
	_pinch_distance = _pointer_separation()
	set_process(false)

#endregion


#region ────────────────────────  running a gesture  ─────────────────────────

func _move_pointer(id: int, position: Vector2) -> void:
	if not _pointers.has(id):
		return
	var previous: Vector2 = _pointers[id]
	_pointers[id] = position

	match _phase:
		Phase.PINCH:
			# Only while both are still down. Lifting one finger leaves the
			# phase at PINCH with a single pointer (see _end_press), and
			# _pointer_separation needs two — the precondition its own comment
			# states, enforced at the one call site that can break it.
			if _pointers.size() == 2:
				_report_pinch()
		Phase.PENDING:
			if id == _primary and position.distance_to(_press_position) >= _slop_pixels():
				_phase = Phase.DRAG
				set_process(false)
				drag_started.emit(_press_position)
				dragged.emit(position, position - _press_position)
		Phase.DRAG:
			if id == _primary:
				dragged.emit(position, position - previous)
		Phase.LONG_PRESS:
			if id == _primary:
				long_press_moved.emit(position)


## Reported as a step, not as a total: the baseline moves to the new separation
## each time, so a listener multiplies its zoom rather than recomputing it from
## a start it would otherwise have to remember.
func _report_pinch() -> void:
	var separation: float = _pointer_separation()
	if _pinch_distance <= 0.0:
		return
	var factor: float = separation / _pinch_distance
	if absf(factor - 1.0) < pinch_deadzone:
		return
	_pinch_distance = separation
	pinched.emit(factor, _pointer_midpoint())

#endregion


#region ─────────────────────────  ending a gesture  ─────────────────────────

func _end_press(id: int, position: Vector2) -> void:
	_pointers.erase(id)

	# Lifting one finger out of a pinch does not hand the gesture back to the
	# other one: the camera would lurch as a zoom became a pan. The survivor
	# has to lift and press again.
	if _phase == Phase.PINCH:
		if _pointers.is_empty():
			_reset()
		return

	if id != _primary:
		return

	match _phase:
		Phase.PENDING:
			tapped.emit(position)
		Phase.DRAG:
			drag_ended.emit(position)
		Phase.LONG_PRESS:
			long_press_ended.emit(position)
	_reset()


func _cancel() -> void:
	if _phase != Phase.IDLE and _phase != Phase.PENDING:
		gesture_cancelled.emit()   # PENDING has told nobody anything yet
	_reset()


func _reset() -> void:
	_phase = Phase.IDLE
	_pointers.clear()
	_primary = -1
	_held_for = 0.0
	_pinch_distance = 0.0
	set_process(false)

#endregion


#region ─────────────────────────────  helpers  ──────────────────────────────

## Read per press rather than cached: rotating a phone changes the short side.
func _slop_pixels() -> float:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return minf(size.x, size.y) * drag_slop_ratio


## Callers must have exactly two pointers down. Indexing past the end is the
## loud failure we want if some path ever gets here with one.
func _pointer_separation() -> float:
	var points: Array[Vector2] = _pointers.values()
	return points[0].distance_to(points[1])


func _pointer_midpoint() -> Vector2:
	var points: Array[Vector2] = _pointers.values()
	return (points[0] + points[1]) * 0.5


func _is_gesture_button(button: int) -> bool:
	return button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT

#endregion
