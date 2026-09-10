extends Node
class_name SquadStateMachine

signal state_changed(new_state: State)


var current_state:State
@export var states: Dictionary[GlobalEnums.WHEEL_SLOT, State] = {}

func start(first_state: State) -> void:
	if first_state == null:
		first_state = states.get(GlobalEnums.WHEEL_SLOT.DEFAULT)
	if first_state == null:
		push_error("StateMachine on %s has no usable state." % get_parent().name)
		return
	current_state = first_state
	current_state.enter()

func change_state(new_state: State) -> void:
	if new_state == null or new_state == current_state:
		return
	current_state.exit()
	current_state = new_state
	current_state.enter()
	state_changed.emit(new_state)


func state_machine_process(delta: float) -> void:
	if current_state:
		current_state.state_update(delta)

func state_machine_physics_process(delta: float) -> void:
	if current_state:
		var new_state:State = current_state.state_physics_update(delta)
		if new_state:
			change_state(new_state)
