extends State
## Pack up and move. No shooting — that is what buys the extra speed.

func state_physics_update(delta: float) -> State:
	if not parent.movement.advance(delta):
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]
	return null
