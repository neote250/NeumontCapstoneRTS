extends State

func enter() -> void:
	super()
	#connect to animations here, maybe should have all animations set in a child of the squad. 
	#That way there doesn't need to be multiple references
	
	#temp until can click enemy units
	#parent.has_target = true





###fire each weapon if within range, else move closer to target
func state_physics_update(_delta: float) -> State:
	#need to do the other half of if target_squad is dead, signal to attacking squad that it has no target anymore
	if not is_instance_valid(parent.target_squad):
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]
	#if !parent.has_target:
		#return parent.state_machine.states[GlobalEnums.STATES.READY]
	
	parent.set_target_position(parent.target_squad.global_position) 

	if !parent.check_range():
		parent.move_to(_delta)
	else:
		for unit: Unit in parent.all_units:
			parent.fire_weapon(unit.weapon_component, _delta)
	
	return null
