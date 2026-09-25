extends Node
class_name State
## One order a squad can be under. States decide what the squad does this
## frame and when to hand over; they never mutate the machine themselves —
## returning a State from state_physics_update() is how a transition is asked for.


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Presentation")
## TODO unread. The hook for playing a clip on enter(), once units have an
## AnimationPlayer. See the animation notes in the refactor plan.
@export var animation_name: String

@export_group("Movement")
## TODO unread. Intended as a per-state speed cap — March packs up and moves
## fast, Warpath advances slowly under arms. Wire it into MovementComponent.step().
@export var move_speed: float = 4

@export_group("Wiring")
## The squad this state gives orders to. Set by NodePath in every squad scene.
@export var parent: Squad
@export_group("")

#endregion


#region ───────────────────────  entering and leaving  ───────────────────────

###Setup when entering the state
func enter() -> void:
	#parent.animations.play(animation_name)
	pass

###Requirements when exiting the state
func exit() -> void:
	pass

#endregion


#region ────────────────────────────  per-frame  ─────────────────────────────

###Handle processes in the state that need to run faster than framerate
func state_update(_delta: float) -> State:
	return null

###Handle processes in the state that do not need to run faster than framerate
func state_physics_update(_delta: float) -> State:
	return null

###Handle player input specific for the state
func state_input(_event:InputEvent) -> State:
	return null

#endregion


#region ──────────────────────────────  policy  ──────────────────────────────

## Does this state pick its own targets? States that do take over weapon
## control; everything else leaves the squad's passive stance running.
func controls_weapons() -> bool:
	return false

#endregion
