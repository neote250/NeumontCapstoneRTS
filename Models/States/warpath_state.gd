extends State
## Advance under arms. Slower than March, but shoots whatever comes into
## range on the way — regardless of stance, which is the point of the order.

func controls_weapons() -> bool:
	return true

func state_physics_update(delta: float) -> State:
	if not parent.movement.advance(delta):
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]
	parent.engage_nearest(delta)
	return null
