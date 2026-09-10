extends CharacterBody3D
class_name Squad

#signals
signal selected(selected_squad:Squad)
	#signal for when entire squad dies
signal squad_terminated(terminated_squad:Squad)
	#signal to game controller to deal damage to target squad
signal damage_dealt(attacker: Squad, attack:Attack, gm_target_squad: Squad)

signal roster_changed(squad: Squad)



## Every tuning number for this squad type. Read-only at runtime.
@export var stats: SquadStats

## The squad's units: membership, formation and per-unit ground clamping.
@export var roster: RosterComponent
## Who we are shooting at, and whether we can reach them.
@export var targeting: TargetingComponent
## Navigation and steering for the body.
@export var movement: MovementComponent


#owning player 
@export var player_id: int = 0
@export var controller:RTSController



func price_of(upgrade: GlobalEnums.UPGRADE_TYPE) -> float:
	match upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:  return float(stats.unit_cost)
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD: return float(stats.squad_cost)
		_:                                  return 0.0

#Upgrades
@export var upgrades:Array[Build]

enum SQUAD_TYPE{PEOPLE, BUILDING, TURRET}
@export var squad_type: SQUAD_TYPE = SQUAD_TYPE.PEOPLE

#state machine stuff
@export var state_machine: SquadStateMachine
@export var default_state: State
@export var stance: GlobalEnums.STANCE = GlobalEnums.STANCE.RETURN_FIRE


#camera
@onready var camera_mount: Node3D = $CameraMount

enum PurchaseResult { OK, SQUAD_FULL, NO_SUCH_BUILD, ALREADY_BUILDING, NO_CONTROLLER }

func _ready() -> void:
	# Announce the mistake by name rather than dying on a null deref.
	if stats == null:
		stats = SquadStats.new()
		push_warning("Squad '%s' has no SquadStats assigned — using defaults." % name)
	
	# The roster owns the units; Squad only republishes what it announces.
	roster.changed.connect(func(_n: int) -> void: roster_changed.emit(self))
	roster.emptied.connect(_on_emptied)
	roster.spawn_to_size()      # must be here — see the note in RosterComponent
	
	state_machine.start(default_state)
	input_event.connect(_on_input_event)
	
	set_process(false)


#Emit to Controller what squad was clicked
func select() -> void:
	#is_selected = true
	selected.emit(self)




##
func vision_contribution() -> float:
	return stats.vision_per_unit * roster.size()

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event.is_action_pressed("target_command"):
		select()
		#get_viewport().set_input_as_handled()


## Halt, and forget what you were chasing. Two components, one order.
## TODO should this also drop the squad back to its default state?
func stop_movement() -> void:
	movement.stop()
	targeting.remove_target()





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







func squad_spawn_position() -> Vector3:
	# In FRONT of this squad, not at a fixed world offset.
	return global_position - global_transform.basis.z * stats.squad_spawn_distance

func add_squad(scene: PackedScene) -> bool:
	if controller == null:
		return false
	return controller.add_squad(scene, squad_spawn_position()) != null

	


@export var weapon_to_grant: PackedScene

func try_spend(amount: float) -> bool:
	if controller == null or controller.memory_shards < amount:
		return false
	controller.memory_shards -= amount
	return true

## Player-facing. May this build start? If so, start it.
func request_build(build: Build) -> PurchaseResult:
	if controller == null:
		return PurchaseResult.NO_CONTROLLER
	if build.is_building:
		return PurchaseResult.ALREADY_BUILDING
	match build.type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			if not roster.has_room():
				return PurchaseResult.SQUAD_FULL
		# future types add their own gates here, in one place
	build.is_building = true
	return PurchaseResult.OK

## Player-facing. Starts a recruit; does not spend (Build drains over time).
func buy_unit() -> PurchaseResult:
	var build: Build = find_build(GlobalEnums.UPGRADE_TYPE.BUY_UNIT)
	if build == null:
		return PurchaseResult.NO_SUCH_BUILD
	return request_build(build)

func find_build(type: GlobalEnums.UPGRADE_TYPE) -> Build:
	for upgrade: Build in upgrades:
		if upgrade.type_of_upgrade == type:
			return upgrade
	return null


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


func is_building_anything() -> bool:
	for upgrade: Build in upgrades:
		if upgrade.is_building:
			return true
	return false



func get_active_builds() -> Array[Build]:
	var active: Array[Build] = []
	for upgrade: Build in upgrades:
		if upgrade.is_building:
			active.append(upgrade)
	return active

func is_build_state_active() -> bool:
	return state_machine.current_state is BuildState




## The last unit died. Stop being findable by range queries this frame, then go.
func _on_emptied() -> void:
	set_physics_process(false)
	collision_layer = 0            # stop being found by range queries NOW
	squad_terminated.emit(self)
	queue_free()


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
	
