extends State
class_name BuildState

@export var speed_multiplier: float = 1.0
@export var cost_multiplier: float = 1.0


##If there is something building, check if have resources to continue building.
func state_physics_update(delta: float) -> State:
	##check resources to see if can build for each build currently upgrading
	for upgrade:Build in parent.economy.upgrades:
		if upgrade.is_building:
			upgrade.check_build(delta, speed_multiplier, cost_multiplier)
	return null
