extends Control

#pointer to current model (unit/building) being controlled
var current_controlled

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var selection_wheel: Control = $CanvasLayer/Selection_Wheel
@onready var testing_data_label: Label = $TestingDataLabel



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func change_testing_data_text(text) -> void:
	if typeof(text) == TYPE_STRING:
		testing_data_label.text = text
	if typeof(text) == TYPE_INT:
		testing_data_label.text = text
	if typeof(text) == TYPE_VECTOR2:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.y)
	if typeof(text) == TYPE_VECTOR3:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.z)










# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("input_wheel"):
		$CanvasLayer/Selection_Wheel.show()
	elif Input.is_action_just_released("input_wheel"):
		var selection = $CanvasLayer/Selection_Wheel.Close()
		#then change the state of the unit being controlled with the selection
		
	
	
