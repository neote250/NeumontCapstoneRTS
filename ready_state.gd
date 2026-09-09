extends State


func enter() -> void:
	super()


func state_physics_update(_delta: float) -> State:
	var closest_squad:Squad = parent.closest_squad_in_range()
	if closest_squad:
		parent.set_target(closest_squad)
		for unit:Unit in parent.all_units:
			
			parent.fire_weapon(unit.weapon_component, _delta)
	else:
		parent.set_target(null)
	return null
