extends BuildState

@export var heat_per_second: float = 12.0
@export var heat_limit: float = 100.0
var heat: float = 0.0

func enter() -> void:
	super()
	heat = 0.0



func state_physics_update(delta: float) -> State:
	var next_state: State = super(delta)    # run the shared build logic
	if next_state:
		return next_state
	heat += heat_per_second * delta
	if heat >= heat_limit:
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]   # overheat, drop out
	return null
