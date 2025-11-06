extends CharacterBody3D
class_name Squad

#signals   !!!!!!! Need to rework these signals
signal selected
signal deselected
	#signal for when entire squad dies
signal squad_terminated(terminated_squad)
	#signal to game controller to deal damage to target squad
signal GM_Deal_Damage(attack:Attack, gm_target_squad: Squad)


#movement
@onready var nav_agent_3d: NavigationAgent3D = $NavigationAgent3D
#animation for walking
@export var speed: int = 500
const smoothing_factor: float = 0.1




#so the ui knows which squad it is, assigned during ownership to owning player's rts controller
var squad_index: int
#owning player 
@export var player_id: int = 0
#targetting
var target_position: Vector3
var has_target: bool = false
@export var target_squad: Squad

#variable unit info, obviously currently pointless
var unit_type: Unit
var max_squad_size: int = 5
var unit_default_attack: Attack


#unit array stuff
@export var all_units: Array[Unit] = []
var current_unit_index: int = 0
var current_unit: Unit
var last_unit_index: int = -1


#state machine stuff
@export var state_machine: PlayerStateMachine



#camera
@onready var camera_mount: Node3D = $CameraMount


func _ready() -> void:
	#everytime a unit in the squad dies, I want to know and be able to do required upkeep
	for unit in all_units:
		unit.health_component.died.connect(remove_unit)
		unit.weapon_component.deal_damage.connect(gm_deal_damage)
	#for unit: Unit in all_units:
		#if !unit.weapon_component.CurrentAttack:
			#unit.weapon_component.CurrentAttack == unit_default_attack


#use these two signals to inform the UI of the squads details
#func select():
	#is_selected = true
	#selected.emit(self)
#func deselect():
	#is_selected = false
	#deselected.emit(self)


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
func set_target_position(target_position: Vector3) -> void:
	nav_agent_3d.target_position = target_position
	

###Movement of the squad
func move_to(delta) -> State:
	#get direction
	var next_path_position = nav_agent_3d.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	direction.y = 0
	
	#face the right direction
	var current_facing = -global_transform.basis.z
	var new_direction_facing = current_facing.slerp(direction, smoothing_factor).normalized()
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




###currently this function checks the distance from Unit 1 to the target squad
func check_range() -> bool:
	if get_xz_distance_to_location(target_position) < all_units[0].attack_range:
		return true
	return false






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



#nonfunctional
#add another unit to the squad
func spawn_unit():
	#currently doesn't make sense, needs update
	var new_unit: Unit = unit_type
	self.add_child(new_unit)
	all_units.append(new_unit)
	#new_unit.add_to_group("units_in_group")
	new_unit.health_component.died.connect(remove_unit)

#nonfunctional
#remove a unit from the squad
func remove_unit(removed_unit: Unit):
	#check if no more units in squad
	if all_units.is_empty():
		squad_terminated.emit(self)
		
		


func remove_squad():
	queue_free()




#return this squad's camera mount
func get_camera_mount():
	return camera_mount








#handling movement at framerate
func _physics_process(delta: float) -> void:
	#make sure squad node is on floor
	if not is_on_floor():
		velocity += get_gravity() * delta
		move_and_slide()
		return
	
	#call the current state's physics process
	state_machine.state_machine_physics_process(delta)
	#move_to(delta)


func _process(delta: float) -> void:
	#call the current state's process
	#state_machine.state_machine_process(delta)
	pass
