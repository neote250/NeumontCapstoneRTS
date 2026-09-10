extends CharacterBody3D
class_name Squad

#signals
signal selected(selected_squad:Squad)
	#signal for when entire squad dies
signal squad_terminated(terminated_squad:Squad)
	#signal to game controller to deal damage to target squad
signal damage_dealt(attacker: Squad, attack:Attack, gm_target_squad: Squad)

signal roster_changed(squad: Squad)


#movement
@onready var nav_agent_3d: NavigationAgent3D = $NavigationAgent3D
#animation for walking
@export var speed: int = 5
const smoothing_factor: float = 0.1


#owning player 
@export var player_id: int = 0
@export var controller:RTSController
#targetting
var target_position: Vector3
var target_squad: Squad
var _range_shape: SphereShape3D = SphereShape3D.new()
var _range_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

#variable unit info, obviously currently pointless until different unit squad types
@export var unit_type:PackedScene = preload("res://Models/unit.tscn")

#squad builder
@export var squad_spawn_distance: float = 10.0
# per-squad-type pricing, set in the inspector on each squad scene
@export var squad_cost: int = 50

func price_of(upgrade: GlobalEnums.UPGRADE_TYPE) -> float:
	match upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:  return float(unit_cost)
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD: return float(squad_cost)
		_:                                  return 0.0

#Unit Builder
@export var max_squad_size: int = 3
@export var spawning_size:int = 3
@export var unit_cost:int = 10

#Upgrades
@export var upgrades:Array[Build]

enum SQUAD_TYPE{PEOPLE, BUILDING, TURRET}
@export var squad_type: SQUAD_TYPE = SQUAD_TYPE.PEOPLE

#Unit ground stuff
const GROUND_MASK: int = 2
var _ground_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _stagger: int = 0
@export var _is_flying:bool = false

#unit array stuff
@export var all_units: Array[Unit] = []
@export var unit_spots: Array[Marker3D]

#state machine stuff
@export var state_machine: SquadStateMachine
@export var default_state: State
@export var stance: GlobalEnums.STANCE = GlobalEnums.STANCE.RETURN_FIRE


#camera
@onready var camera_mount: Node3D = $CameraMount

enum PurchaseResult { OK, SQUAD_FULL, NO_SUCH_BUILD, ALREADY_BUILDING, NO_CONTROLLER }

func _ready() -> void:
	##Ensure there is at least 1 unit in the squad
	if all_units.is_empty():
		all_units.assign(NodeUtil.children_of_type(self, Unit))
	
	##Ensure unit spots are properly set
	if unit_spots.is_empty():
		unit_spots.assign(NodeUtil.children_of_type(self, Marker3D))
	
	##Connect default units
	for unit:Unit in all_units:
		connect_signals(unit)
	
	##Create missing units (connects while adding)
	var size_difference: int = spawning_size - all_units.size()
	if size_difference>=1:
		for i:int in range(size_difference):
			add_unit()
		
	
	state_machine.start(default_state)
	input_event.connect(_on_input_event)
	
	##Collision setup?
	_range_query.shape = _range_shape
	_range_query.collision_mask = collision_layer
	_range_query.exclude = [get_rid()]
	
	set_process(false)


#Emit to Controller what squad was clicked
func select() -> void:
	#is_selected = true
	selected.emit(self)


@export var vision_per_unit: float = 0.0    ## 0 on infantry, ~8 on buildings


##
func vision_contribution() -> float:
	return vision_per_unit * all_units.size()

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event.is_action_pressed("target_command"):
		select()
		#get_viewport().set_input_as_handled()


###Don't manually set target, use this function
func set_target(target: Squad) -> void:
	target_squad = target

###Don't manually remove target, use this function
func remove_target() -> void:
	target_squad = null

###Consider differences between this and remove target function
func stop_movement() -> void:
	nav_agent_3d.target_position = global_position
	velocity = Vector3.ZERO
	target_squad = null
	#also change state to stop??             ???????/

###Don't manually set target position, use this function
func set_target_position(new_target: Vector3) -> void:
	target_position = new_target
	nav_agent_3d.target_position = new_target


###Movement of the squad
func move_to(delta:float) -> State:
	#get direction
	var next_path_position: Vector3 = nav_agent_3d.get_next_path_position()
	var direction: Vector3 = (next_path_position - global_position).normalized()
	direction.y = 0
	
	#face the right direction
	var current_facing: Vector3 = -global_transform.basis.z
	var new_direction_facing: Vector3 = current_facing.slerp(direction, smoothing_factor).normalized()
	look_at(global_position + new_direction_facing, Vector3.UP)
	
	var desired: Vector3 = direction * speed
	velocity.x = lerp(velocity.x, desired.x, smoothing_factor)
	velocity.z = lerp(velocity.z, desired.z, smoothing_factor)   # leave velocity.y to gravity
	move_and_slide()
	return null



func _snap_units_to_ground() -> void:
	if _is_flying:
		return
	if all_units.is_empty():
		return
	# One unit per frame — a 5-unit squad fully refreshes 12×/second.
	_stagger = (_stagger + 1) % all_units.size()
	var unit: Unit = all_units[_stagger]
	_ground_query.from = unit.global_position + Vector3.UP * 5.0
	_ground_query.to = unit.global_position + Vector3.DOWN * 20.0
	_ground_query.collision_mask = GROUND_MASK
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ground_query)
	if hit:
		unit.global_position.y = hit.position.y

func _snap_to_ground() -> void:
	_ground_query.from = global_position + Vector3.UP * 5.0
	_ground_query.to = global_position + Vector3.DOWN * 20.0
	_ground_query.collision_mask = GROUND_MASK
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ground_query)
	if hit:
		global_position.y = hit.position.y

##Who in the squad absorbs it? Up 1 level from bottom
func take_damage(attack: Attack) -> void:
	if all_units.is_empty():
		return
	var victim: Unit = random_unit_in_squad()
	var amount: int = Combat.resolve(attack, victim.health_component.armor_type)
	victim.health_component.apply_damage(amount)
	#if unit number changed, update ui and other numbers
	


###Emit signal to Game Manager and handle updates on the attacking squad (like ammunition depletion)
func on_damage_dealt(attack: Attack) -> void:
	damage_dealt.emit(self, attack, target_squad)


###For the selected unit, use the current attack and do the associated animations
func fire_weapon(weapon_component:WeaponComponent, delta:float) -> void:
	weapon_component.damage_target(delta)
	#and call the connected animation
	
	return




##currently this function checks the distance from Unit 1 to the target squad
func check_range() -> bool:
	if all_units.is_empty() or not is_instance_valid(target_squad):
		return false
	var attack: Attack = all_units[0].weapon_component.current_attack
	if attack == null:
		return false
	#return get_xz_distance_to_location(target_squad.global_position) < attack.attack_range
	return is_within_xz_range(target_squad.global_position, attack.attack_range)


##Isn't actually random, returns closest squad
func closest_squad_in_range() -> Squad:
	if all_units.is_empty():
		return null
	var attack: Attack = all_units[0].weapon_component.current_attack
	if attack == null:
		return null
	_range_shape.radius = attack.attack_range
	_range_query.transform = global_transform

	var results: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(_range_query)
	var closest_distance: float = INF
	var closest_body: Squad = null
	for result: Dictionary in results:
		var body: Node = result["collider"]
		if body is Squad and Teams.is_hostile(player_id, (body as Squad).player_id):
			var d: float = global_position.distance_squared_to(body.global_position)
			if d < closest_distance:
				closest_distance = d
				closest_body = body
	return closest_body

#Distance Checks

##get actual horizontal distance, not just check if in rsange
func get_xz_distance_to_location(location: Vector3) -> float:
	var dx: float = location.x - global_position.x
	var dz: float = location.z - global_position.z
	return sqrt(dx*dx + dz*dz)


func random_unit_in_squad() -> Unit:
	var random_unit_index: int = randi() % all_units.size()
	return all_units[random_unit_index]

##Ignoring y in the range check is correct and should stay. [br]
##The reason is design, not performance: a squad on a hill 15 m above another should still be in weapon range, 
##and using true 3D distance would let elevation silently eat the range budget, 
##making combat unpredictable on slopes. [br]Nearly every RTS does horizontal-only range for exactly this.
func is_within_xz_range(location: Vector3, radius: float) -> bool:
	var dx: float = location.x - global_position.x
	var dz: float = location.z - global_position.z
	return dx * dx + dz * dz < radius * radius   # no square root

func squad_spawn_position() -> Vector3:
	# In FRONT of this squad, not at a fixed world offset.
	return global_position - global_transform.basis.z * squad_spawn_distance

func add_squad(scene: PackedScene) -> bool:
	if controller == null:
		return false
	return controller.add_squad(scene, squad_spawn_position()) != null


func has_room() -> bool:
	return all_units.size() < mini(max_squad_size, unit_spots.size())
	


@export var weapon_to_grant: PackedScene

func grant_weapon(attack_scene: PackedScene) -> bool:
	if attack_scene == null or all_units.is_empty():
		return false
	for unit: Unit in all_units:
		var atk: Attack = attack_scene.instantiate() as Attack
		unit.weapon_component.add_child(atk)
		unit.weapon_component.attack_options.append(atk)
		if unit.weapon_component.current_attack == null:
			unit.weapon_component.current_attack = atk
	return true

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
			if not has_room():
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

## Mechanic. Called by Build.complete(), by _ready() for the starting units,
## and by the debug hotkey. Never touches shards.
## TODO tell the RTS controller to increase vision when the roster grows.
## TODO disable the UI's recruit button once the squad is at max size.
func add_unit() -> bool:
	if not has_room():
		return false
	var spot: Marker3D = unit_spots[all_units.size()]
	var new_unit: Unit = unit_type.instantiate() as Unit
	add_child(new_unit)
	new_unit.global_position = spot.global_position
	new_unit.global_rotation = global_rotation
	connect_signals(new_unit)
	all_units.append(new_unit)
	roster_changed.emit(self)
	return true

func find_build(type: GlobalEnums.UPGRADE_TYPE) -> Build:
	for upgrade: Build in upgrades:
		if upgrade.type_of_upgrade == type:
			return upgrade
	return null


## Fire at the nearest hostile, according to stance. Runs for any state
## that does not control weapons itself.
func _passive_fire(delta: float) -> void:
	if stance == GlobalEnums.STANCE.HOLD_FIRE:
		set_target(null)
		return
	if all_units.is_empty():
		return
	var threat: Squad = closest_squad_in_range()
	set_target(threat)          # damage_dealt reads target_squad — not optional
	if threat == null:
		return
	for unit: Unit in all_units:
		unit.weapon_component.damage_target(delta)

#remove a unit from the squad
func remove_unit(removed_unit: Unit) -> void:
	all_units.erase(removed_unit)
	removed_unit.queue_free()
	roster_changed.emit(self)
	#check if no more units in squad
	if all_units.is_empty():
		set_physics_process(false)
		collision_layer = 0            # stop being found by range queries NOW
		squad_terminated.emit(self)
		queue_free()


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

func connect_signals(_unit:Unit)->void:
	_unit.health_component.died.connect(remove_unit)
	_unit.weapon_component.deal_damage.connect(on_damage_dealt)


@export var formation_catchup_speed: float = 6.0
const FORMATION_ARRIVAL_THRESHOLD: float = 0.05

## Move each unit toward its formation slot. Local space throughout —
## x and z only, because _snap_units_to_ground() owns y.
func align_to_squad_default_placement(delta: float) -> void:
	for i: int in all_units.size():
		if i >= unit_spots.size():
			break
		var unit: Unit = all_units[i]
		var slot: Vector3 = unit_spots[i].position   # local to the squad

		var offset: Vector3 = slot - unit.position   # local minus local = local
		offset.y = 0.0                               # ground pass owns y
		var distance: float = offset.length()

		if distance <= FORMATION_ARRIVAL_THRESHOLD:
			unit.position.x = slot.x                 # settle exactly, stop jittering
			unit.position.z = slot.z
			continue
		
		# Never step further than the remaining distance — no overshoot, no oscillation.
		var step: float = minf(formation_catchup_speed * delta, distance)
		var move: Vector3 = offset / distance * step
		unit.position.x += move.x
		unit.position.z += move.z


#handling movement at framerate
func _physics_process(delta: float) -> void:
	state_machine.state_machine_physics_process(delta)  # 1. squad moves x/z
	if not state_machine.current_state.controls_weapons():
		_passive_fire(delta)
	_snap_to_ground()                                    # y, exact
	align_to_squad_default_placement(delta)             # 2. units close on slots (local)
	_snap_units_to_ground()                             # 3. y from terrain (global)
	
