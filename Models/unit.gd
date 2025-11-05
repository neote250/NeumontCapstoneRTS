extends CharacterBody3D
class_name Unit



#info given to units
var target_position: Vector3
var can_move: bool = true
var has_target_position = true
var is_moving: bool = false
var is_attacking: bool = false


#unit stats
@export var speed: float = 5.0
@export var health_component : HealthComponent
@export var weapon_component : WeaponComponent
@export var default_attack: Attack

#this is the only thing the unit does, consider a way to reduce amount of constant processes
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		move_and_slide()
		return

func _process(delta: float) -> void:
	# Add the gravity.

	
	#if can_move and has_target_position:
		## Apply desired movement to velocity
		#var direction = (target_position - global_position).normalized()
	#else:
		#velocity.x = 0
		#velocity.y = 0
	

	
	#move_and_slide()
	pass
