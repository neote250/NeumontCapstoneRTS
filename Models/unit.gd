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



#unit type info                        !!!!!!

func killed():
	#animations and stuff here           !!!!!!
	
	#when a unit dies, inform squad
	
	queue_free()



func damage(attack:Attack):
	if health_component:
		health_component.damage(attack)
	#if this is too expensive, consider doing on a squad basis, rather than a unit basis
	#if is_damage_negatively_modified:
		#current_negative_mod_timer -= delta
		#if current_negative_mod_timer <= 0:
			#current_negative_mod_timer == 0
			#is_damage_negatively_modified = false
			#if is_damage_positively_modified:
				#damage = current_positive_modifier
	#
	#if is_damage_positively_modified:
		#current_positive_mod_timer -= delta
		#if current_positive_mod_timer <= 0:
			#current_positive_mod_timer == 0
			#is_damage_positively_modified = false
			#if is_damage_negatively_modified:
				#damage = current_negative_modifier
		#var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		#var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		#if move_dir:
			#velocity.x = move_dir.x * move_speed
			#velocity.z = move_dir.z * move_speed
		#else:
		#velocity.x = move_toward(velocity.x, 0, speed)
		#velocity.z = move_toward(velocity.z, 0, speed)


func _process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		move_and_slide()
		return
	
	if can_move and has_target_position:
		# Apply desired movement to velocity
		var direction = (target_position - global_position).normalized()
		
		#var simplified_global_position = Vector3(global_position.x, 0, global_position.z)
		#var simplified_target_position = Vector3(target_position.x, 0, target_position.z)
		#if simplified_global_position.distance_to(simplified_target_position) > 10:
			#velocity.x = move_toward(global_position.x, target_position.x, speed)
			#velocity.z = move_toward(global_position.z, target_position.z, speed)
			#print(simplified_global_position)
		#else:
			#has_target_position = false

	else:
		velocity.x = 0
		velocity.y = 0
	

	
	move_and_slide()
