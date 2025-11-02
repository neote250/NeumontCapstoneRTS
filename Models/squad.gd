extends CharacterBody3D
class_name Squad


#movement
@onready var nav_agent_3d: NavigationAgent3D = $NavigationAgent3D
#animation for walking
@export var speed: int = 150
const smoothing_factor := 0.1

#signals   !!!!!!! Need to rework these signals
signal selected
signal deselected
	#signal for when entire squad dies
signal squad_terminated(terminated_squad)


#targetting
var is_selected: bool = false
var target_position: Vector3
var has_target: bool = false
var squad_index: int
var target_squad

#variable unit info, obviously currently pointless
var unit_type = preload("res://Models/unit.tscn")
var max_squad_size: int = 5

#unit array stuff
@export var all_units: Array[Unit] = []
var current_unit_index: int = 0
var current_unit: Unit
var last_unit_index: int = -1

#camera
@onready var camera_mount: Node3D = $CameraMount

func _ready() -> void:
	for unit in all_units:
		unit.health_component.died.connect(remove_unit)


#use these two signals to inform the UI of the squads details
func select():
	is_selected = true
	selected.emit(self)
#
func deselect():
	is_selected = false
	deselected.emit(self)



func set_target(target_position: Vector3):
	pass

func set_target_position(target_position: Vector3):
	nav_agent_3d.target_position = target_position

#movement of the squad
func move_to(delta):
	#nav_agent_3d.target_position = target_position
	
	#make sure squad node is on floor
	if not is_on_floor():
		velocity += get_gravity() * delta
		move_and_slide()
		return
	
	#if done, don't need to do rest
	if nav_agent_3d.is_navigation_finished():
		return
	
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
	
	
	
	
	#for unit in all_units:
		#unit.target_position = target_position + unit.position
		#has_target = true
		#unit.has_target_position = true
		#unit.velocity = unit.velocity.lerp(direction * speed * delta, smoothing_factor)
		#unit.move_and_slide()
	


func stop_movement():
	has_target = false
	target_position = self.position




#add another unit to the squad
func spawn_unit():
	var new_unit: Unit = unit_type
	self.add_child(new_unit)
	new_unit.add_to_group("units_in_group")
	new_unit.health_component.died.connect(remove_unit)

#remove a unit from the squad
func remove_unit(removed_unit: Unit):
	#check if no more units in squad
	if all_units.is_empty():
		squad_terminated.emit(self)
		self.queue_free()
	
	



func get_camera_mount():
	return camera_mount



#handling movement at framerate
func _physics_process(delta: float) -> void:
	move_to(delta)


func _process(delta: float) -> void:
	
	pass
