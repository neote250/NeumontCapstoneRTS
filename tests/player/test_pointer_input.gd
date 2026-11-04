extends PointerTestCase
## PointerInput's gesture state machine: which signal a press turns into, and
## just as importantly which ones it must not. Every assertion on fired()
## checks the whole ordered list, so an extra signal fails the test too.

const AT: Vector2 = Vector2(400.0, 300.0)


# --- tap ---------------------------------------------------------------------

func test_press_and_release_is_a_tap() -> void:
	touch_down(AT)
	touch_up(AT)
	assert_eq(fired(), ["tapped"] as Array[String])
	# Doubles as a check on the fixture: a position that is off by a constant
	# factor here means _send() lost its in_local_coords flag, and every other
	# position assertion in this file is failing for that one reason.
	assert_eq(args("tapped")[0], AT,
			"the release position: where the order goes. viewport %s" % tree.root.get_visible_rect().size)


func test_a_wobble_is_still_a_tap() -> void:
	var wobbled: Vector2 = AT + Vector2(slop() - 1.0, 0.0)
	touch_down(AT)
	touch_move(wobbled)
	touch_up(wobbled)
	assert_eq(fired(), ["tapped"] as Array[String], "inside the slop radius: no drag")


# --- drag --------------------------------------------------------------------

## The bisect for everything below. If this passes while the slop-relative test
## under it fails, the two sides disagree about the threshold; if this fails
## too, ScreenDrag events are not reaching _move_pointer at all. The failure
## message carries the numbers either way, so one run tells us which.
func test_a_move_far_past_any_slop_starts_a_drag() -> void:
	touch_down(AT)
	touch_move(AT + FAR)
	assert_eq(count("drag_started"), 1,
			"moved %s px; viewport %s, so slop is %s px" % [FAR.x, tree.root.get_visible_rect().size, slop()])
	assert_eq(fired(), ["drag_started", "dragged"] as Array[String])


func test_the_drag_begins_where_the_finger_went_down() -> void:
	touch_down(AT)
	touch_move(AT + FAR)
	touch_up(AT + FAR)
	assert_eq(fired(), ["drag_started", "dragged", "drag_ended"] as Array[String])
	assert_eq(args("drag_started")[0], AT, "not where it crossed the threshold")


func test_the_slop_radius_is_where_a_drag_starts() -> void:
	var past: Vector2 = AT + Vector2(slop() + 1.0, 0.0)
	touch_down(AT)
	touch_move(past)
	assert_eq(count("drag_started"), 1,
			"one px past the radius; viewport %s, slop %s px" % [tree.root.get_visible_rect().size, slop()])


func test_the_first_step_is_measured_from_the_press() -> void:
	# Not from the slop boundary: the camera must not quietly lose that first
	# stretch of pan. The helpers never set the event's own `relative`, so this
	# also shows the step is PointerInput's own arithmetic.
	touch_down(AT)
	touch_move(AT + FAR)
	assert_eq(args("dragged")[1], FAR)


func test_later_steps_are_steps_not_totals() -> void:
	var second: Vector2 = AT + FAR + Vector2(5.0, 7.0)
	touch_down(AT)
	touch_move(AT + FAR)
	touch_move(second)
	assert_eq(count("dragged"), 2)
	assert_eq(last_args("dragged")[0], second)
	assert_eq(last_args("dragged")[1], Vector2(5.0, 7.0), "the move since the last one")


# --- long press --------------------------------------------------------------

func test_holding_still_opens_the_wheel() -> void:
	touch_down(AT)
	await wait_seconds(LONG_PRESS * 2.0)
	assert_eq(fired(), ["long_press_started"] as Array[String])
	assert_eq(args("long_press_started")[0], AT, "the wheel opens under the thumb")


func test_the_wheel_tracks_the_finger_and_commits_on_release() -> void:
	var slid: Vector2 = AT + Vector2(100.0, 0.0)
	touch_down(AT)
	await wait_seconds(LONG_PRESS * 2.0)
	touch_move(slid)
	touch_up(slid)
	assert_eq(fired(), ["long_press_started", "long_press_moved", "long_press_ended"] as Array[String])
	assert_eq(count("tapped"), 0, "a hold is not also a tap")


func test_an_open_wheel_does_not_also_pan() -> void:
	touch_down(AT)
	await wait_seconds(LONG_PRESS * 2.0)
	touch_move(AT + Vector2(300.0, 300.0))
	assert_eq(count("drag_started"), 0, "the finger is choosing a wedge, not moving the camera")


# --- which gesture wins ------------------------------------------------------

func test_a_drag_beats_the_timer() -> void:
	touch_down(AT)
	touch_move(AT + FAR)
	await wait_seconds(LONG_PRESS * 3.0)
	assert_eq(count("long_press_started"), 0, "once it is a pan, waiting does not open the wheel")


# --- pinch -------------------------------------------------------------------

func test_two_fingers_moving_apart_pinch_out() -> void:
	touch_down(Vector2(400.0, 300.0), 0)
	touch_down(Vector2(500.0, 300.0), 1)      # 100 apart
	touch_move(Vector2(600.0, 300.0), 1)      # 200 apart
	assert_eq(count("pinched"), 1)
	assert_almost(args("pinched")[0], 2.0, 0.001, "twice as far apart")
	assert_eq(args("pinched")[1], Vector2(500.0, 300.0), "centred between the fingers")


func test_two_fingers_coming_together_pinch_in() -> void:
	touch_down(Vector2(400.0, 300.0), 0)
	touch_down(Vector2(600.0, 300.0), 1)
	touch_move(Vector2(500.0, 300.0), 1)
	assert_almost(args("pinched")[0], 0.5, 0.001)


func test_a_pinch_reports_steps_so_a_listener_multiplies() -> void:
	touch_down(Vector2(400.0, 300.0), 0)
	touch_down(Vector2(500.0, 300.0), 1)
	touch_move(Vector2(600.0, 300.0), 1)      # 100 -> 200
	touch_move(Vector2(800.0, 300.0), 1)      # 200 -> 400
	assert_eq(count("pinched"), 2)
	assert_almost(args("pinched")[0], 2.0, 0.001)
	assert_almost(last_args("pinched")[0], 2.0, 0.001, "rebased each time, not 4.0 since the start")


func test_a_small_squeeze_is_ignored() -> void:
	touch_down(Vector2(400.0, 300.0), 0)
	touch_down(Vector2(500.0, 300.0), 1)
	touch_move(Vector2(501.0, 300.0), 1)      # 1%, deadzone is 2%
	assert_eq(count("pinched"), 0, "two fingers resting is not a zoom")


func test_a_second_finger_closes_off_a_drag() -> void:
	touch_down(AT, 0)
	touch_move(AT + FAR, 0)
	touch_down(AT + Vector2(300.0, 0.0), 1)
	assert_eq(fired(), ["drag_started", "dragged", "drag_ended"] as Array[String],
			"the pan is ended before the zoom starts")


func test_a_second_finger_cancels_an_open_wheel() -> void:
	touch_down(AT, 0)
	await wait_seconds(LONG_PRESS * 2.0)
	touch_down(AT + Vector2(200.0, 0.0), 1)
	assert_eq(count("gesture_cancelled"), 1, "the wheel has to come off the screen")
	assert_eq(count("long_press_ended"), 0, "and nothing is committed")


func test_lifting_one_finger_does_not_resume_a_drag() -> void:
	touch_down(Vector2(400.0, 300.0), 0)
	touch_down(Vector2(500.0, 300.0), 1)
	touch_up(Vector2(500.0, 300.0), 1)
	touch_move(Vector2(300.0, 300.0), 0)
	assert_eq(count("drag_started"), 0, "the camera would lurch from a zoom into a pan")
	assert_eq(count("tapped"), 0)


func test_the_last_finger_leaving_a_pinch_resets() -> void:
	touch_down(Vector2(400.0, 300.0), 0)
	touch_down(Vector2(500.0, 300.0), 1)
	touch_up(Vector2(500.0, 300.0), 1)
	touch_up(Vector2(400.0, 300.0), 0)
	clear()
	touch_down(AT)
	touch_up(AT)
	assert_eq(fired(), ["tapped"] as Array[String], "back to idle: the next press works")


# --- being interrupted -------------------------------------------------------

func test_the_os_taking_the_touch_cancels_the_wheel() -> void:
	touch_down(AT)
	await wait_seconds(LONG_PRESS * 2.0)
	touch_cancel(AT)
	assert_eq(count("gesture_cancelled"), 1)
	assert_eq(count("long_press_ended"), 0, "an interruption is not a choice")


func test_a_cancelled_press_that_told_nobody_stays_quiet() -> void:
	touch_down(AT)
	touch_cancel(AT)
	assert_eq(fired(), [] as Array[String], "nothing was on screen to undo")


func test_losing_focus_releases_the_pointer() -> void:
	# The important half is the second assertion. A gesture left open would make
	# _input swallow every pointer event from then on: the game keeps running
	# and stops responding to touch, which is a miserable thing to debug.
	touch_down(AT)
	await wait_seconds(LONG_PRESS * 2.0)
	# Node.* qualified: this test is a RefCounted, so the bare constant — which
	# pointer_input.gd can use — is not in scope here.
	pointer.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(count("gesture_cancelled"), 1)
	clear()
	touch_down(AT)
	touch_up(AT)
	assert_eq(fired(), ["tapped"] as Array[String], "not stuck eating input")


# --- the mouse, the editor's stand-in for a thumb ---------------------------

func test_left_click_is_a_tap() -> void:
	mouse_down(AT)
	mouse_up(AT)
	assert_eq(fired(), ["tapped"] as Array[String])


func test_a_held_left_button_opens_the_wheel_on_the_timer() -> void:
	mouse_down(AT)
	await wait_seconds(LONG_PRESS * 2.0)
	assert_eq(fired(), ["long_press_started"] as Array[String], "the same path a finger takes")


func test_right_mouse_opens_the_wheel_without_the_wait() -> void:
	var slid: Vector2 = AT + Vector2(80.0, 0.0)
	mouse_down(AT, MOUSE_BUTTON_RIGHT)
	assert_eq(fired(), ["long_press_started"] as Array[String], "no timer on desktop")
	mouse_move(slid)
	mouse_up(slid, MOUSE_BUTTON_RIGHT)
	assert_eq(fired(), ["long_press_started", "long_press_moved", "long_press_ended"] as Array[String])


func test_the_scroll_wheel_stands_in_for_a_pinch() -> void:
	wheel(true, AT)
	assert_almost(args("pinched")[0], pointer.wheel_step, 0.0001, "scrolling up zooms in")
	clear()
	wheel(false, AT)
	assert_almost(args("pinched")[0], 1.0 / pointer.wheel_step, 0.0001)
