extends Node
class_name SquadStateMachine
## Holds the squad's current order and swaps between them. Deliberately thin:
## a state returning a State from state_physics_update() is what asks for a
## transition, so the machine never needs to know what any state means.


#region ─────────────────────────────  signals  ──────────────────────────────

signal state_changed(new_state: State)

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

## Which state answers each wheel slot. Every squad scene maps these itself,
## so the same wedge can mean different orders on infantry and on a building.
@export var states: Dictionary[GlobalEnums.WHEEL_SLOT, State] = {}

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

var current_state: State

#endregion


#region ───────────────────────────  transitions  ────────────────────────────

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

#endregion


#region ────────────────────────────  per-frame  ─────────────────────────────

func state_machine_process(delta: float) -> void:
	if current_state:
		current_state.state_update(delta)

func state_machine_physics_process(delta: float) -> void:
	if current_state:
		var new_state:State = current_state.state_physics_update(delta)
		if new_state:
			change_state(new_state)

#endregion
