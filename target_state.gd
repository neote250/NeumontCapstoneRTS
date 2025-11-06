extends State

func Enter() -> void:
	super()
	#connect to animations here, maybe should have all animations set in a child of the squad. 
	#That way there doesn't need to be multiple references
	
	#temp until can click enemy units
	parent.has_target = true

func Exit() -> void:
	
	pass

###For the selected unit, use the current attack and do the associated animations
func fire_weapon(weapon_component:WeaponComponent, delta:float) -> void:
	weapon_component.damage_target(delta)
	#and call the connected animation
	
	return




func State_Input(event:InputEvent) -> State:
	return null

func State_Update(_delta: float) -> State:
	return null

###fire each weapon if within range, else move closer to target
func State_Physics_Update(_delta: float) -> State:
	#need to do the other half of if target_squad is dead, signal to attacking squad that it has no target anymore
	if !parent.has_target:
		return parent.state_machine.states[GlobalEnums.STATES.READY]
	
	for unit: Unit in parent.all_units:
		fire_weapon(unit.weapon_component, _delta)
	
	return null
