extends CanvasLayer

#pointer to current model (unit/building) being controlled
var current_controlled




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("input_wheel"):
		$Selection_Wheel.show()
	elif Input.is_action_just_released("input_wheel"):
		var selection = $Selection_Wheel.Close()
		#then change the state of the unit being controlled with the selection
		
	
	
