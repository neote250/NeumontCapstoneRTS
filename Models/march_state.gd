extends State


func state_physics_update(_delta: float) -> State:
	#if done, don't need to do rest
	if parent.nav_agent_3d.is_navigation_finished():
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]
	parent.move_to(_delta)
	return null
