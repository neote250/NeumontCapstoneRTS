extends State


func Enter() -> void:
	super()

func Exit() -> void:
	pass

func State_Input(event:InputEvent) -> State:
	return null

func State_Update(_delta: float) -> State:
	return null


func State_Physics_Update(_delta: float) -> State:
	var closest_squad:Squad = parent.closest_squad_in_range()
	if closest_squad:
		parent.set_target(closest_squad)
		for unit:Unit in parent.all_units:
			
			parent.fire_weapon(unit.weapon_component, _delta)
	else:
		parent.set_target(null)
	return null
