extends State


func controls_weapons() -> bool:
	return true

func state_physics_update(_delta: float) -> State:
	if parent.nav_agent_3d.is_navigation_finished():
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]
	parent.move_to(_delta)
	
	#If target is within range, attack them
	#otherwise attack closest target within range
	
	var closest_squad:Squad = parent.closest_squad_in_range()
	if closest_squad:
		parent.set_target(closest_squad)
		for unit:Unit in parent.all_units:
			
			parent.fire_weapon(unit.weapon_component, _delta)
	else:
		parent.set_target(null)
	return null
