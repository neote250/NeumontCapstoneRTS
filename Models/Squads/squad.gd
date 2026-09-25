extends CharacterBody3D
class_name Squad
## A squad is an identity — whose it is, what it is called, how it fights —
## plus four components. It routes and it decides; it does very little itself.
##
## The rule for what lives here: a method stays on Squad only if it makes a
## decision spanning more than one component. Anything that just forwards
## belongs on the component it forwards to.


#region ─────────────────────────────  signals  ──────────────────────────────

signal selected(selected_squad: Squad)
## The whole squad died. The Game Manager owns what that means for the match.
signal squad_terminated(terminated_squad: Squad)
## A unit fired. Routed to the Game Manager, which decides whether it lands.
signal damage_dealt(attacker: Squad, attack: Attack, gm_target_squad: Squad)
## Republished from RosterComponent so the UI can stay coupled to Squad.
signal roster_changed(squad: Squad)

#endregion


#region ────────────────────────────  constants  ─────────────────────────────

enum SQUAD_TYPE { PEOPLE, BUILDING, TURRET }
## Every squad is in this group, so an owner can find its squads without
## knowing where in the tree they sit.
const GROUP: StringName = &"squads"

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Components")
## Every tuning number for this squad type. Read-only at runtime.
@export var stats: SquadStats
## The units: membership, formation and per-unit ground clamping.
@export var roster: RosterComponent
## Who we are shooting at, and whether we can reach them.
@export var targeting: TargetingComponent
## Navigation and steering for the body.
@export var movement: MovementComponent
## What this squad can buy, what it costs, and whether it may start.
@export var economy: EconomyComponent

@export_group("Ownership")
## Who owns this squad — the one ownership record. player_id and every
## hostility check follow from it.
@export var controller: Controller
## Legitimately unused until there is a second unit type.
@export var squad_type: SQUAD_TYPE = SQUAD_TYPE.PEOPLE

@export_group("Orders")
@export var state_machine: SquadStateMachine
@export var default_state: State
## Whether the squad defends itself when its state is not controlling weapons.
@export var stance: GlobalEnums.STANCE = GlobalEnums.STANCE.RETURN_FIRE
@export_group("")

#endregion


#region ─────────────────────────  node references  ──────────────────────────

@onready var camera_mount: Node3D = $CameraMount

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## Derived, never stored: always the owner's id, so changing controller is the
## whole of changing sides. A write is refused loudly — a property with only a
## getter would ignore it without a word.
var player_id: int:
	get:
		return controller.player_id
	set(_value):
		push_error("Squad '%s': player_id is derived from controller. Assign controller instead." % name)

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

## Joined here rather than in _ready(): every node in a scene enters the tree
## before any node in it is ready, so a controller's scan in its own _ready()
## sees every squad, whatever the tree order.
func _enter_tree() -> void:
	add_to_group(GROUP)

func _ready() -> void:
	# Announce the mistake by name rather than dying on a null deref.
	if stats == null:
		stats = SquadStats.new()
		push_warning("Squad '%s' has no SquadStats assigned — using defaults." % name)
	if controller == null:
		push_error("Squad '%s' has no controller. Every squad has an owner — a player, or the map's NeutralController." % name)

	# The roster owns the units; Squad only republishes what it announces.
	roster.changed.connect(func(_n: int) -> void: roster_changed.emit(self))
	roster.emptied.connect(_on_emptied)
	roster.spawn_to_size()      # must be here — see the note in RosterComponent

	state_machine.start(default_state)
	input_event.connect(_on_input_event)

	set_process(false)

## Order matters: the body moves, the body lands, the units close on their slots
## in local space, then the units land. Swapping 3 and 4 makes units chase a
## slot that is still moving.
func _physics_process(delta: float) -> void:
	state_machine.state_machine_physics_process(delta)   # 1. body moves x/z
	if not state_machine.current_state.controls_weapons():
		_passive_fire(delta)
	movement.snap_to_ground()                            # 2. body y, exact
	roster.align_to_slots(delta)                         # 3. units close on slots
	roster.snap_to_ground()                              # 4. unit y from terrain

#endregion


#region ──────────────────────────────  orders  ──────────────────────────────

## Halt, and forget what you were chasing. Two components, one order.
## TODO should this also drop the squad back to its default state?
func stop_movement() -> void:
	movement.stop()
	targeting.remove_target()

#endregion


#region ──────────────────────────────  combat  ──────────────────────────────

## Acquire the nearest hostile and fire on it. Returns the threat, or null.
## Ignores stance — callers that should respect it go through _passive_fire().
func engage_nearest(delta: float) -> Squad:
	var threat: Squad = targeting.nearest_hostile()
	targeting.set_target(threat)   # damage_dealt reads it — not optional
	if threat == null:
		return null
	roster.fire_all(delta)
	return threat

## Fire at the nearest hostile, according to stance. Runs for any state
## that does not control weapons itself.
func _passive_fire(delta: float) -> void:
	if stance == GlobalEnums.STANCE.HOLD_FIRE:
		targeting.remove_target()
		return
	if roster.is_empty():
		return
	engage_nearest(delta)

##Who in the squad absorbs it? Up 1 level from bottom
func take_damage(attack: Attack) -> void:
	if roster.is_empty():
		return
	var victim: Unit = roster.random_unit()
	var amount: int = Combat.resolve(attack, victim.health_component.armor_type)
	victim.health_component.apply_damage(amount)
	#if unit number changed, update ui and other numbers

###Emit signal to Game Manager and handle updates on the attacking squad (like ammunition depletion)
func on_damage_dealt(attack: Attack) -> void:
	damage_dealt.emit(self, attack, targeting.target)

#endregion


#region ────────────────────────────  selection  ─────────────────────────────

#Emit to Controller what squad was clicked
func select() -> void:
	#is_selected = true
	selected.emit(self)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event.is_action_pressed("target_command"):
		select()
		#get_viewport().set_input_as_handled()

#endregion


#region ─────────────────────────────  queries  ──────────────────────────────

##
func vision_contribution() -> float:
	return stats.vision_per_unit * roster.size()

func is_build_state_active() -> bool:
	return state_machine.current_state is BuildState

#endregion


#region ──────────────────────────────  death  ───────────────────────────────

## The last unit died. Stop being findable by range queries this frame, then go.
func _on_emptied() -> void:
	set_physics_process(false)
	collision_layer = 0            # stop being found by range queries NOW
	squad_terminated.emit(self)
	queue_free()

#endregion
