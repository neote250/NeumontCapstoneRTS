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


#Camera stuff
@onready var camera: Camera3D = $Camera3D
@onready var current_camera_mount: Node3D = $BuildingSquad.get_camera_mount()
@onready var minimap: SubViewport= $MinimapContainer/SubViewportContainer/Minimap
@onready var minimap_camera: Camera3D = $MinimapContainer/SubViewportContainer/Minimap/Camera3D

var map_coordinates: Vector2 = Vector2(256.0, 256.0)


var memory_shards: float = 50.0


#ui stuff
@onready var ui: Player_UI = $UI
@onready var move_marker: Sprite3D = $MinimapContainer/SubViewportContainer/Minimap/MoveMarker

var all_progress_bars:Dictionary[Squad, BuildProgress]




func _ready() -> void:
	#Squad setup
	if all_squads.is_empty():
		var child_nodes:Array[Node] = get_children()
		for node:Node in child_nodes:
			if node is Squad:
				all_squads.append(node)
	
	set_active_squad(0)
	
	#Camera setup
	$"../NavigationRegion3D/Terrain3D".set_camera(camera)
	camera.global_transform = current_camera_mount.global_transform
	update_camera_target()
	
	#Signal setup
	ui.Change_State.connect(Player_State_Input)
	
	###connect to each squad's target marker and signals.
	for _squad:Squad in all_squads:
		connect_signals(_squad)

func connect_signals(_squad:Squad)->void:
	_squad.Controller_Add_Squad.connect(Build_Squad)
	#_squad.RTS_Controller_Check_Progress.connect(add_squad)



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("next_squad"):  # Tab key or SWIPE_RIGHT
		cycle_next_squad()
	elif event.is_action_pressed("previous_squad"):  # Shift+Tab or SWIPE_LEFT
		cycle_previous_squad()
	
	
	# Command to buy unit for current squad
	if event.is_action_pressed("buy_unit"):
		current_squad.buy_unit()
	
	
	# Commands for current squad
	if event.is_action_pressed("target_command"):  # currently left click eventually TOUCH		and current_squad
		player_click_on_map()
	elif event.is_action_pressed("stop_command"):  # ... or ... 
		current_squad.stop_movement()


func Player_State_Input(new_state: GlobalEnums.STATES) -> void:
	current_squad.state_machine.change_state(current_squad.state_machine.states[new_state])

func add_squad(which_squad:Squad, _progress:float, _cost:float, _multiplier:float)->void:
	if memory_shards >= _cost:
		memory_shards -= _cost
		which_squad.progress_build(_progress, _multiplier)
	else:
		return

func Build_Squad(where_to_place:Vector3, bought_squad:PackedScene) -> void:
	var new_squad:Squad = bought_squad.instantiate()
	add_child(new_squad)
	
	##Position in world
	new_squad.global_position = Vector3(
		#unit_spots[all_units.size()].global_position.x, 
		#all_units[0].global_position.y, 
		#unit_spots[all_units.size()].global_position.z
		where_to_place.x,
		where_to_place.y,
		where_to_place.z-10
		)
	#new_squad.global_rotation = all_units[0].global_rotation
	
	
	###Connect to any squad -> controller signals
	connect_signals(new_squad)
	
	all_squads.append(new_squad)
	





func cycle_next_squad() -> void:
	if all_squads.size() <= 1:
		return
	
	#ui.clear_prev_squad()
	
	var next_index:int = (current_squad_index + 1) % all_squads.size()
	set_active_squad(next_index)

func cycle_previous_squad() -> void:
	if all_squads.size() <= 1:
		return
	
	#ui.clear_prev_squad()
	
	var prev_index: int = current_squad_index - 1
	if prev_index < 0:
		prev_index = all_squads.size() - 1
	set_active_squad(prev_index)


func set_active_squad(index: int) -> void:
	# Set new active squad
	current_squad_index = index
	current_squad = all_squads[index]
	
	# Update camera to follow new squad
	current_camera_mount = current_squad.camera_mount
	update_camera_target()
	
	#Update UI
	ui.update_player_unit_details(current_squad)
	
	# Emit signal for UI updates
	swap_squad.emit(current_squad_index)

###Option for player to increase minimap size on LONG press or SHIFT
func increase_minimap_scale() -> void:
	pass


###Handle result of a mouse click on map
func player_click_on_map() -> void:
	var mouse_pos: Vector2 = minimap.get_mouse_position() #get the mouse position based on the subviewport
	
	#Create the vector
	var from: Vector3 = minimap_camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + minimap_camera.project_ray_normal(mouse_pos) * 1000
	#Setup data
	var space_state:PhysicsDirectSpaceState3D = minimap_camera.get_world_3d().direct_space_state
	var land_hit_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 2)
	#var squad_hit_query = PhysicsRayQueryParameters3D.create(from, to, 3)
	
	
	#Get results
	var result: Dictionary = space_state.intersect_ray(land_hit_query)
	
	#Check if result is a squad otherwise it is a position (or not a result)
	
	if result:
		current_squad.set_target_position(result.position)
		###DEBUG
		ui.change_testing_data_text(result.position)
	else: return
	
	# Add visual feedback at target position
	enable_move_marker(result.position)

###Handle result of a finger press on map
func player_press_on_map() -> void:
	pass






###VISUALS


### This is for instant swap of camera position.
func update_camera_target() -> void:
	if camera:
		camera.global_position = current_camera_mount.global_position
		camera.rotation = current_camera_mount.rotation


### Visual feedback for move command
func enable_move_marker(position: Vector3) -> void:
	#var marker = move_marker.instantiate()
	#get_tree().current_scene.add_child(marker)
	
	move_marker.global_position = position
	move_marker.visible = true
	#marker.play_animation()  # Fade out over time
	







func _process(delta: float) -> void:
	if !current_squad:
		cycle_next_squad()
	
	#keep following the current squad's camera mount
	camera.position = camera.position.lerp(current_camera_mount.global_position, 5.0 * delta)
	#update rotation as well
	camera.rotation = current_squad.rotation
	
