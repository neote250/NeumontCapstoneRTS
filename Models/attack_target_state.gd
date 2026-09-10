extends State
class_name AttackTargetState
## Chase and shoot one specific target. Infantry pursue a target that walks
## out of range; a turret cannot, so it only fires when the target comes to it.
##
## TODO connect to animations here. Might be better to have all animations set
## in a child of the squad, so there don't need to be multiple references.

## Infantry chase a fleeing target. Turrets don't.
@export var pursue: bool = true


func controls_weapons() -> bool:
	return true


func state_physics_update(delta: float) -> State:
	# Target died or was freed — hand control back to the default slot.
	# TODO the other half: tell the attacking squad it has lost its target.
	if not parent.targeting.has_target():
		return parent.state_machine.states[GlobalEnums.WHEEL_SLOT.DEFAULT]

	parent.movement.set_destination(parent.targeting.target.global_position)

	if parent.targeting.target_in_range():
		parent.roster.fire_all(delta)
	elif pursue:
		parent.movement.step(delta)
	return null
