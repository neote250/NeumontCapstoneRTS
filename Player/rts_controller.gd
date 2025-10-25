extends Node
class_name RTSController

#signals
	#tells UI that current squad index has changed
signal swap_squad(squad_index: int)
	#tells UI that something about the current squad has changed
signal squad_changed(squad_index: int) #also modifiers and num of units????
	#tells UI that total squads have changed
signal added_squad(new_squad: Squad, squad_index: int, total_squads: int)
signal removed_squad(removed_squad: Squad, squad_index: int, total_squads: int)

#squads
var all_squads: Array[Squad] = []
var current_squad_index: int = 0
var current_squad: Squad = null
var last_squad_index: int = -1

#Reference to UI
#Don't have a squadinfopanel yet. need to make one
#@onready var ui_manager = $"../UI/SquadInfoPanel"

#Camera Nodes
@onready var camera := $Camera3D
@onready var current_camera_mount := $StartingSquad/CameraMount
@onready var minimap := $MinimapContainer/SubViewportContainer/Minimap


func _ready() -> void:
	# Find all squads in scene
	refresh_squad_list()
	#set initial squad
	if all_squads.size() > 0:
		set_active_squad(0)
	
	
	#camera stuff
	$"../Terrain3D".set_camera(camera)
	camera.global_transform = current_camera_mount.global_transform
	
	
	# Set camera to StartingSquad camera mount position
	update_camera_target()

func refresh_squad_list():
	all_squads.clear()
	var player_squads = get_tree().get_nodes_in_group("player_squads")
	
	for squad in player_squads:
		if squad is Squad:
			all_squads.append(squad)
	
	# Sort by squad_id for consistent ordering   ####NEEDED???
	#all_squads.sort_custom(func(a, b): return a.squad_id < b.squad_id)



func _input(event):
	if event.is_action_pressed("next_squad"):  # Tab key or SWIPE_RIGHT
		cycle_next_squad()
	elif event.is_action_pressed("previous_squad"):  # Shift+Tab or SWIPE_LEFT
		cycle_previous_squad()
	
	
	#elif event.is_action_pressed("quick_swap"):  # Q key - swap between last two squads
		#quick_swap()
	## Direct squad selection with number keys
	#for i in range(1, 10):
		#if event.is_action_pressed("select_squad_" + str(i)):
			#if i - 1 < all_units.size():
				#set_active_unit(i - 1)
	
	
	
	
	# Commands for current squad
	if event.is_action_pressed("target_command") and current_squad:  # right click or TOUCH
		issue_move_command()
	elif event.is_action_pressed("stop_command") and current_squad:  # ... or CENTER_RADIAL
		current_squad.stop_movement()

func cycle_next_squad():
	if all_squads.size() <= 1:
		return
	
	var next_index = (current_squad_index + 1) % all_squads.size()
	set_active_squad(next_index)

func cycle_previous_squad():
	if all_squads.size() <= 1:
		return
	
	var prev_index = current_squad_index - 1
	if prev_index < 0:
		prev_index = all_squads.size() - 1
	set_active_squad(prev_index)



#func quick_swap():
	#if last_squad_index >= 0 and last_squad_index < all_squads.size():
		#set_active_squad(last_squad_index)

func set_active_squad(index: int):
	#check to see if something went wrong, prob not needed, but check for now
	if index >= all_squads.size():
		return
	
	## Store last squad for quick swap
	#if current_squad:
		#last_squad_index = current_squad_index
		#current_squad.deactivate()
	
	# Set new active squad
	current_squad_index = index
	current_squad = all_squads[index]
	#current_squad.activate()
	
	
	# Update camera to follow new squad
	current_camera_mount = current_squad.camera_mount
	update_camera_target()
	
	
	# Emit signal for UI updates
	swap_squad.emit(current_squad_index)

func issue_move_command():
	#currently only for mouse, need to set up for touch     !!!!!!!!!!
	var mouse_pos = minimap.get_mouse_position()
	var camera = minimap.get_camera_3d()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		current_squad.move_to(result.position)
		# Add visual feedback at target position
		spawn_move_marker(result.position)


# Update current squad before calling this function. 
# This is for instant swap of camera position. Not for camera follow??
func update_camera_target():
	if camera:
		camera.global_position = current_camera_mount.global_position




#Separate hour job to get this working
func spawn_move_marker(position: Vector3):
	# Visual feedback for move command
	#var marker = preload("res://MoveMarker.tscn").instantiate()
	#get_tree().current_scene.add_child(marker)
	#marker.global_position = position
	#marker.play_animation()  # Fade out over time
	pass



##
#func get_squad_status(squad: Squad) -> String:
	#if squad.has_target:
		#return "Moving"
	#elif squad.is_active:
		#return "Active"
	#else:
		#return "Idle"





func _process(delta: float) -> void:
	#keep following the current squad's camera mount
	camera.position = camera.position.lerp(current_camera_mount.global_position, 5.0 * delta)
	#update rotation as well
	
	#camera.global_position = current_squad.all_units[0].global_position + Vector3(0,5,0)
