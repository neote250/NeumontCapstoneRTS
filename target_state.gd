extends State

func Enter() -> void:
	super()
	#connect to animations here, maybe should have all animations set in a child of the squad. 
	#That way there doesn't need to be multiple references
	
	#temp until can click enemy units
	#parent.has_target = true

func Exit() -> void:
	
	pass



func State_Input(event:InputEvent) -> State:
	return null

func State_Update(_delta: float) -> State:
	return null

###fire each weapon if within range, else move closer to target
func State_Physics_Update(_delta: float) -> State:
	#need to do the other half of if target_squad is dead, signal to attacking squad that it has no target anymore
	if !parent.target_squad:# or !parent.has_target:
		return parent.state_machine.states[GlobalEnums.STATES.CENTER]
	#if !parent.has_target:
		#return parent.state_machine.states[GlobalEnums.STATES.READY]
	
	parent.set_target_position(parent.target_squad.global_position) 
	#var _distance = parent.check_range()
	#if parent.all_units[0].weapon_component.CurrentAttack.attack_range < _distance:
	if !parent.check_range():
		parent.move_to(_delta)
	else:
		for unit: Unit in parent.all_units:
			parent.fire_weapon(unit.weapon_component, _delta)
	
	return null
