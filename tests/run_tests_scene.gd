extends Node
## Editor test runner: open tests/run_tests.tscn and press F6 (Run Current Scene).
## Results appear in the Output panel at the bottom of the editor; the last line
## says how many passed and failed. The game window shows that line too, and
## closes by itself a few seconds later.


func _ready() -> void:
	# _ready() runs while Godot is still adding this scene to the root window,
	# and the root refuses new children until that finishes ("Parent node is
	# busy setting up children"). Tests add nodes to the root, so wait one frame
	# first — the same rule as [[guards-and-ready-order]] in the game code.
	await get_tree().process_frame
	var failed: int = await RtsTestRunner.run_all(get_tree())
	var summary: String = str(get_tree().root.get_meta(&"rts_test_summary", ""))
	_show(summary, failed == 0)
	# The editor's Output panel gets the game's output a little later, over its
	# debugger connection; lines printed just before the game quits can be lost
	# on the way. So wait a moment before closing, and say it once more.
	await get_tree().create_timer(2.0, true, false, true).timeout
	print("Tests finished: %s" % summary)
	await get_tree().create_timer(1.0, true, false, true).timeout
	get_tree().quit(0 if failed == 0 else 1)


## The result in big letters in the game window, green or red.
func _show(summary: String, all_passed: bool) -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label: Label = Label.new()
	label.text = summary
	label.add_theme_font_size_override(&"font_size", 32)
	label.add_theme_color_override(&"font_color", Color(0.5, 1.0, 0.6) if all_passed else Color(1.0, 0.5, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	layer.add_child(shade)
	layer.add_child(label)
	add_child(layer)
