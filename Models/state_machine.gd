extends Node
class_name PlayerStateMachine

#@export var ready_state: State
#@export var target_state: State
#@export var warpath_state: State
#@export var march_state: State
#@export var skirmish_state: State

#starting state can be used to have units spawn with commands. also for story mode missions starting chasing or the like
@export var starting_state:State
var current_state:State
@export var states: Dictionary[GlobalEnums.STATES, State] = {}
@onready var parent: Squad = $".."

#for child in get_children():
	#if child is State:
		#states[child.name.to_lower()] = child
		#child.Transitioned.connect(on_child_transition)
func _ready() -> void:
	if starting_state:
		starting_state.Enter()
		current_state = starting_state
	else:
		current_state = states[GlobalEnums.STATES.READY]
	
	change_state(starting_state)


func change_state(new_state: State):
	if current_state:
		current_state.Exit()
	
	current_state = new_state
	current_state.Enter()


func state_machine_process(delta: float) -> void:
	if current_state:
		current_state.State_Update(delta)

func state_machine_physics_process(delta: float) -> void:
	if current_state:
		var new_state = current_state.State_Physics_Update(delta)
		if new_state:
			change_state(new_state)

#func on_child_transition(state, new_state_name):
	#if state != current_state: # double check this logic
		#return
	#
	#var new_state = states.get(new_state_name.to_lower())
	#if !new_state:
		#return
	#
	#if current_state:
		#current_state.Exit()
	#
	#new_state.Enter()
	#
	#current_state = new_state
