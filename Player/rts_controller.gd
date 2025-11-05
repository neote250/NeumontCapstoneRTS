extends Node
class_name RTSController

#signals
	#tells game manager that current squad controlled has changed (game manager tells ui)
signal swap_squad(squad_index: int)
	#tells game manager that something about the current squad details have changed
signal squad_changed(squad_index: int)
	#tells UI that total squads have changed
signal added_squad(new_squad: Squad, squad_index: int, total_squads: int)
signal removed_squad(removed_squad: Squad, squad_index: int, total_squads: int)

#squads
@export var all_squads: Array[Squad] = []
var current_squad_index: int = 0
var current_squad: Squad = null
var last_squad_index: int = -1

#Reference to UI
#Don't have a squadinfopanel yet. need to make one
#@onready var ui_manager = $"../UI/SquadInfoPanel"

#Camera stuff
@onready var camera: Camera3D = $Camera3D
@onready var current_camera_mount: Node3D = $StartingSquad.get_camera_mount()
@onready var minimap: SubViewport= $MinimapContainer/SubViewportContainer/Minimap
@onready var minimap_camera: Camera3D = $MinimapContainer/SubViewportContainer/Minimap/Camera3D

var map_coordinates: Vector2 = Vector2(256.0, 256.0)


#ui stuff
@onready var ui: Player_UI = $UI
@export var move_marker: Resource

func _ready() -> void:
	#Squad setup
	if all_squads.size() > 0:
		set_active_squad(0)
	
	
	#Camera setup
	$"../NavigationRegion3D/Terrain3D".set_camera(camera)
	camera.global_transform = current_camera_mount.global_transform
	update_camera_target()
	
	#Signal setup
	ui.Change_State.connect(Player_State_Input)





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
	if event.is_action_pressed("target_command") and current_squad:  # currently left click eventually TOUCH
		player_click_on_map()
	elif event.is_action_pressed("stop_command") and current_squad:  # ... or ... 
		current_squad.stop_movement()


func Player_State_Input(new_state: GlobalEnums.STATES):
	current_squad.state_machine.change_state(current_squad.state_machine.states[new_state])

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

###Option for player to increase minimap size on LONG press or SHIFT
func increase_minimap_scale():
	pass


###Handle result of a mouse click on map
func player_click_on_map():
	var mouse_pos = minimap.get_mouse_position() #get the mouse position based on the subviewport
	
	#Create the vector
	var from = minimap_camera.project_ray_origin(mouse_pos)
	var to = from + minimap_camera.project_ray_normal(mouse_pos) * 1000
	#Setup data
	var space_state = minimap_camera.get_world_3d().direct_space_state
	var land_hit_query = PhysicsRayQueryParameters3D.create(from, to, 2)
	var squad_hit_query = PhysicsRayQueryParameters3D.create(from, to, 3)
	
	
	#Get results
	var result = space_state.intersect_ray(land_hit_query)
	
	#Check if result is a squad otherwise it is a position (or not a result)
	
	if result:
		current_squad.set_target_position(result.position)
		###DEBUG
		ui.change_testing_data_text(result.position)
	else: return
	
	# Add visual feedback at target position
	spawn_move_marker(result.position)

###Handle result of a finger press on map
func player_press_on_map():
	pass






###VISUALS


### This is for instant swap of camera position.
func update_camera_target():
	if camera:
		camera.global_position = current_camera_mount.global_position


### Visual feedback for move command
func spawn_move_marker(position: Vector3):
	#var marker = move_marker.instantiate()
	
	#get_tree().current_scene.add_child(marker)
	#marker.global_position = position
	#marker.play_animation()  # Fade out over time
	pass







func _process(delta: float) -> void:
	#keep following the current squad's camera mount
	camera.position = camera.position.lerp(current_camera_mount.global_position, 5.0 * delta)
	#update rotation as well
	camera.rotation.x = current_squad.rotation.x
	camera.rotation.y = current_squad.rotation.y
