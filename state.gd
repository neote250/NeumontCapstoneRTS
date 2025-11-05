extends Node
class_name State

@export var animation_name: String
@export var move_speed: float = 400

@export var parent: Squad

#
#signal Transitioned

###Setup when entering the state
func Enter() -> void:
	#parent.animations.play(animation_name)
	pass

###Requirements when exiting the state
func Exit() -> void:
	pass

###Handle player input specific for the state
func State_Input(event:InputEvent) -> State:
	return null

###Handle processes in the state that need to run faster than framerate
func State_Update(_delta: float) -> State:
	return null

###Handle processes in the state that do not need to run faster than framerate
func State_Physics_Update(_delta: float) -> State:
	return null
