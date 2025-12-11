extends State

func Enter() -> void:
	super()
	for upgrade:Build in parent.upgrades:
		if upgrade.is_building:
			parent.current_upgrading.append(upgrade)

func Exit() -> void:
	pass

func State_Input(event:InputEvent) -> State:
	return null

func State_Update(_delta: float) -> State:
	return null


func State_Physics_Update(_delta: float) -> State:
	if parent.upgrades.is_empty():
		var isUpgrading:bool = false
		for upgrade:Build in parent.upgrades:
			if upgrade.is_building:
				isUpgrading = true
		if !isUpgrading:
			return parent.state_machine.states[GlobalEnums.STATES.CENTER]
	
	##check resources to see if can build for each build currently upgrading
	for upgrade in parent.upgrades:
		if upgrade.is_building:
			upgrade.check_build(_delta, 2, 2)
	return null
