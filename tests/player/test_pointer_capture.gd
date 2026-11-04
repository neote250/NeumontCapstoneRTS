extends PointerTestCase
## The two properties the whole _unhandled_input / _input split exists for:
##
## 1. The UI gets first refusal. A press the build panel wanted must not also
##    become a move order in the world underneath — the bug this layer replaced.
## 2. A gesture already in flight is not taken away. A pan that happens to pass
##    over a panel keeps panning, because _input owns the pointer and marks the
##    events handled.
##
## These use mouse events rather than touch. Godot's Control system handles
## mouse buttons directly, and on a device a finger reaches the same code
## through emulate_mouse_from_touch, which is on by default. What is being
## tested is the ordering, and that is the same either way.

const PANEL: Rect2 = Rect2(Vector2(40.0, 40.0), Vector2(200.0, 80.0))
## Clear of the panel, so a press here is a world press.
const OPEN_GROUND: Vector2 = Vector2(600.0, 400.0)

var layer: CanvasLayer
var button: Button
var _button_fired: bool = false


func before_each() -> void:
	await super()
	button = Button.new()
	button.text = "Recruit"
	button.position = PANEL.position
	button.size = PANEL.size
	button.pressed.connect(func() -> void: _button_fired = true)
	layer = CanvasLayer.new()
	layer.add_child(button)
	tree.root.add_child(layer)
	await tree.process_frame


func after_each() -> void:
	if is_instance_valid(layer):
		tree.root.remove_child(layer)
		layer.free()
	await super()


# --- the UI gets first refusal ----------------------------------------------

func test_a_press_on_a_button_never_becomes_a_world_order() -> void:
	mouse_down(PANEL.get_center())
	mouse_up(PANEL.get_center())
	assert_true(_button_fired, "the button did get the click")
	assert_eq(fired(), [] as Array[String], "and nothing went to the world underneath")


func test_a_press_beside_the_button_still_reaches_the_world() -> void:
	mouse_down(OPEN_GROUND)
	mouse_up(OPEN_GROUND)
	assert_false(_button_fired)
	assert_eq(fired(), ["tapped"] as Array[String])


# --- a gesture keeps its pointer ---------------------------------------------

func test_a_pan_is_not_cut_in_half_by_crossing_the_panel() -> void:
	var over: Vector2 = PANEL.get_center()
	var past: Vector2 = PANEL.get_center() + Vector2(0.0, PANEL.size.y)
	mouse_down(OPEN_GROUND)
	mouse_move(OPEN_GROUND + FAR)
	mouse_move(over)                      # straight over the panel
	mouse_move(past)
	mouse_up(past)
	assert_eq(count("dragged"), 3, "every move, including the ones over the panel")
	assert_eq(count("drag_ended"), 1, "and the release still closes it")
	assert_false(_button_fired, "the panel was passed over, not pressed")


func test_the_wheel_keeps_tracking_over_the_panel() -> void:
	mouse_down(OPEN_GROUND, MOUSE_BUTTON_RIGHT)
	mouse_move(PANEL.get_center())
	mouse_up(PANEL.get_center(), MOUSE_BUTTON_RIGHT)
	assert_eq(fired(), ["long_press_started", "long_press_moved", "long_press_ended"] as Array[String],
			"a wedge that happens to sit over the HUD is still choosable")
	assert_false(_button_fired)
