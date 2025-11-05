extends State


func Enter() -> void:
	super()

func Exit() -> void:
	pass

func State_Input(event:InputEvent) -> State:
	return null

func State_Update(_delta: float) -> State:
	return null


func State_Physics_Update(_delta: float) -> State:
	#if done, don't need to do rest
	if parent.nav_agent_3d.is_navigation_finished():
		return parent.state_machine.states[GlobalEnums.STATES.READY]
	parent.move_to(_delta)
	return null
