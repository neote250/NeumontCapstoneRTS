extends Node
class_name State

@export var animation_name: String
@export var move_speed: float = 4

@export var parent: Squad

###Setup when entering the state
func enter() -> void:
	#parent.animations.play(animation_name)
	pass

###Requirements when exiting the state
func exit() -> void:
	pass

###Handle player input specific for the state
func state_input(event:InputEvent) -> State:
	return null

###Handle processes in the state that need to run faster than framerate
func state_update(_delta: float) -> State:
	return null


## Does this state pick its own targets? States that do take over weapon
## control; everything else leaves the squad's passive stance running.
func controls_weapons() -> bool:
	return false

###Handle processes in the state that do not need to run faster than framerate
func state_physics_update(_delta: float) -> State:
	return null
