extends CharacterBody3D
class_name Squad

#signals
signal selected(selected_squad:Squad)
signal deselected
	#signal for when entire squad dies
signal squad_terminated(terminated_squad:Squad)
	#signal to game controller to deal damage to target squad
signal GM_Deal_Damage(attack:Attack, gm_target_squad: Squad)
signal RTS_Controller_Check_Progress(which_squad:Squad, progress:float, cost: float)
signal Controller_Add_Squad(where_to_place:Vector3, type_of_squad_bought:PackedScene)

#movement
@onready var nav_agent_3d: NavigationAgent3D = $NavigationAgent3D
#animation for walking
@export var speed: int = 500
const smoothing_factor: float = 0.1
var fixed_y_position: float = 20.0

@export var buy_unit_upgrade:Build

#so the ui knows which squad it is, assigned during ownership to owning player's rts controller
var squad_index: int
#owning player 
@export var player_id: int = 0
@export var controller:RTSController
#targetting
var target_position: Vector3
var has_target: bool = false
var target_squad: Squad


#variable unit info, obviously currently pointless until different unit squad types
@export var unit_type:PackedScene = preload("res://Models/unit.tscn")
var unit_default_attack: Attack

#Unit Builder
var max_squad_size: int = 5
@export var spawning_size:int = 3
@export var unit_cost:int = 10

#Upgrades
@export var upgrades:Array[Build]
var current_upgrading:Array[Build]

enum SQUAD_TYPE{PEOPLE, BUILDING, TURRET}
@export var squad_type: SQUAD_TYPE = SQUAD_TYPE.PEOPLE




#unit array stuff
@export var all_units: Array[Unit] = []
var current_unit_index: int = 0
var current_unit: Unit
@export var unit_spots: Array[Marker3D]

#state machine stuff
@export var state_machine: PlayerStateMachine
@export var default_state: State


#camera
@onready var camera_mount: Node3D = $CameraMount



func _ready() -> void:
	##Ensure there is at least 1 unit in the squad
	if all_units.is_empty():
		for child: Node in get_children():
			if child is Unit:
				all_units.append(child as Unit)
	
	##Ensure unit spots are properly set
	if unit_spots.is_empty():
		for child: Node in get_children():
			if child is Marker3D:
				unit_spots.append(child as Marker3D)
	
	##Connect default units
	for unit:Unit in all_units:
		connect_signals(unit)
	
	##Create missing units (connects while adding)
	var size_difference: int = spawning_size - all_units.size()
	if size_difference>=1:
		for i:int in range(size_difference):
			add_unit()
		
	
	if upgrades.is_empty():
		for child:Node in get_children():
			if child is Build:
				upgrades.append(child as Build)
	
	##Connect any initial upgrades ####pointless now?
	#if !upgrades.is_empty():
		#for upgrade:Build in upgrades:
			#
	
	
	#for unit: Unit in all_units:
		#if !unit.weapon_component.CurrentAttack:
			#unit.weapon_component.CurrentAttack == unit_default_attack
	state_machine.current_state = default_state
	
	input_event.connect(_on_input_event)


#Emit to Controller what squad was clicked
func select() -> void:
	#is_selected = true
	selected.emit(self)
#func deselect():
	#is_selected = false
	#deselected.emit(self)
	

#func _input(event: InputEvent) -> void:
	#


func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_pressed("target_command") and event.pressed:
		print(self.name)
		#take_damage($WeaponComponent/BasicShot)
		select()
		
		#get_viewport().set_input_as_handled()
	

#func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	#
	#if event.is_action_pressed("target_command"):
		#select()


###Don't manually set target, use this function
func set_target(target: Squad) -> void:
	target_squad = target
	has_target = true

###Don't manually remove target, use this function
func remove_target() -> void:
	target_squad = null
	has_target = false

###Consider differences between this and remove target function
func stop_movement() -> void:
	has_target = false
	target_position = self.position
	#also change state to stop??             ???????/

###Don't manually set target position, use this function
func set_target_position(_target_position: Vector3) -> void:
	_target_position = Vector3(_target_position.x, 20.0, _target_position.z)
	nav_agent_3d.target_position = _target_position
	


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
	
	velocity = velocity.lerp(direction * speed * delta, smoothing_factor)
	move_and_slide()
	return null







###Handle cleanup at the squad level. Up 1 level from bottom damage chain.
func take_damage(attack: Attack) -> void:
	if all_units.size() > 0:
		random_unit_in_squad().health_component.take_damage(attack)
		#if unit number changed, update ui and other numbers
	


###Emit signal to Game Manager and handle updates on the attacking squad (like ammunition depletion)
func gm_deal_damage(attack: Attack) -> void:
	GM_Deal_Damage.emit(attack, target_squad)


###For the selected unit, use the current attack and do the associated animations
func fire_weapon(weapon_component:WeaponComponent, delta:float) -> void:
	weapon_component.damage_target(delta)
	#and call the connected animation
	
	return




###currently this function checks the distance from Unit 1 to the target squad
func check_range() -> bool:
	if all_units.is_empty():
		return false
	var is_in_range:bool = (
						get_xz_distance_to_location(target_position)
	 					< 
						all_units[0].weapon_component.CurrentAttack.attack_range)
	if is_in_range:
		return true
	return false


###Isn't actually random, returns closest squad
func closest_squad_in_range() -> Squad:
	if all_units.is_empty():
		return
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	# Create a sphere query
	var query: Object = PhysicsShapeQueryParameters3D.new()
	var sphere: Object = SphereShape3D.new()
	sphere.radius = all_units[0].weapon_component.CurrentAttack.attack_range
	#print(str(sphere.radius))
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = collision_layer  # Only check same collision layers
	query.exclude = [self]  # Exclude self from results
	
	var results:Array[Dictionary] = space_state.intersect_shape(query)
	
	var closest_distance:float = INF
	var closest_body:Squad = null
	
	for result:Dictionary in results:
		var body = result["collider"]
		# Check if it is a Squad
		if body is Squad:
			var distance: float = global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_body = body
	
	return closest_body
	
	#if get_xz_distance_to_location(target_position) < all_units[0].weapon_component.CurrentAttack.attack_range:
		##return true
		#pass
	##return false
	#return null
	
	
	
	




#Distance Checks
func get_xz_distance_to_location(location: Vector3) -> float:
	var dx: float = target_position.x - global_position.x
	var dz: float = target_position.z - global_position.z
	return sqrt(dx*dx + dz*dz)

func get_xz_distance_to_squad() -> float:
	var dx: float = target_squad.global_position.x - global_position.x
	var dz: float = target_squad.global_position.z - global_position.z
	return sqrt(dx*dx + dz*dz)


func random_unit_in_squad() -> Unit:
	var random_unit_index: int = randi() % all_units.size()
	return all_units[random_unit_index]



##Add another unit to the squad. Spawning it in the designated spot (xz) with another unit's (y)
func buy_unit() -> void:
	#if enough of A and B resource
	if all_units.size() >= max_squad_size:
		#also inform player that the squad is at max size
		return
	add_unit()

func add_unit() -> void:
	##instantiate another unit and do all the ready stuff
	var new_unit:Unit = unit_type.instantiate() as Unit
	add_child(new_unit)
	
	##Position in world
	new_unit.global_position = Vector3(
		unit_spots[all_units.size()].global_position.x, 
		all_units[0].global_position.y, 
		unit_spots[all_units.size()].global_position.z
		)
	new_unit.global_rotation = all_units[0].global_rotation
	
	##Connect signals
	connect_signals(new_unit)
	
	##Finally add to array
	all_units.append(new_unit)
	
	#Disable ui button if max size
	#if all_units.size() >= max_squad_size:
		#controller.ui.build_dict[]



#remove a unit from the squad
func remove_unit(removed_unit: Unit) -> void:
	all_units.erase(removed_unit)
	removed_unit.queue_free()
	#check if no more units in squad
	if all_units.is_empty():
		squad_terminated.emit(self)
		
		






func connect_signals(_unit:Unit)->void:
	_unit.health_component.died.connect(remove_unit)
	_unit.weapon_component.deal_damage.connect(gm_deal_damage)

#return this squad's camera mount
func get_camera_mount() -> Node3D:
	return camera_mount


func align_to_squad_default_placement(delta:float) -> void:
	#var arrival_threshold: float = 1
	#var unit_number_temp:int = 0
	#
	#for unit:Unit in all_units:
		#var _target_position: Vector3 = unit_spots[unit_number_temp].position
		#var difference: Vector3 = _target_position - unit.position
		#difference.y = 0
		#var distance:float = difference.length()
		#
		#if distance > arrival_threshold:
			#var direction: Vector3 = difference.normalized()
			#var arrival_speed:float = min(distance * 5.0, speed)
			#unit.velocity = direction * arrival_speed
		#else:
			#unit.velocity = Vector3.ZERO
			##unit.position = _target_position
			#unit.position.x = _target_position.x
			#unit.position.z = _target_position.z
		#unit.move_and_slide()
		#unit_number_temp+=1
	
	return


#handling movement at framerate
func _physics_process(delta: float) -> void:
	###Squad box doesn't need to be on floor.
	###Priority is making sure x and z dimension movement
	#make sure squad node is on floor
	if not is_on_floor():
		velocity += get_gravity() * delta
		move_and_slide()
		return
	

	##if unit is out of place,move towards spot in squad
	align_to_squad_default_placement(delta)
	
	#call the current state's physics process
	state_machine.state_machine_physics_process(delta)
	#move_to(delta)
	
	#if controller.ui.build_dict.has(buy_unit_upgrade):
		#if controller.ui.build_dict[buy_unit_upgrade].button.toggle_mode:
			#buy_unit_upgrade.check_build(delta, 1, 1)
	


func _process(delta: float) -> void:
	#call the current state's process
	#state_machine.state_machine_process(delta)
	pass
