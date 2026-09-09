extends State
class_name BuildState

@export var speed_multiplier: float = 1.0
@export var cost_multiplier: float = 1.0


func state_input(event:InputEvent) -> State:
	return null

func state_update(_delta: float) -> State:
	return null

##If there is something building, check if have resources to continue building.
func state_physics_update(delta: float) -> State:
	var any_building: bool = false
	##if there is no targetted upgrades, move back to ready state
	#if parent.upgrades.is_empty():
		#var isUpgrading:bool = false
		#for upgrade:Build in parent.upgrades:
			#if upgrade.is_building:
				#isUpgrading = true
		#if !isUpgrading:
			#return parent.state_machine.states[GlobalEnums.STATES.CENTER]
	
	##check resources to see if can build for each build currently upgrading
	for upgrade:Build in parent.upgrades:
		if upgrade.is_building:
			any_building = true
			upgrade.check_build(delta, speed_multiplier, cost_multiplier)
	if not any_building:
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]
	
	return null
