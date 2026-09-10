extends Node
class_name RTSController

#signals
	#tells game manager that current squad controlled has changed (game manager tells ui)
signal swap_squad(new_squad: Squad)
	#tells game manager that something about the current squad details have changed
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
@onready var current_camera_mount: Node3D 
#= $BuildingSquad.get_camera_mount()
@onready var minimap: SubViewport= $MinimapContainer/SubViewportContainer/Minimap
@onready var minimap_camera: Camera3D = $MinimapContainer/SubViewportContainer/Minimap/Camera3D
var _snap_next_frame: bool = true

var map_coordinates: Vector2 = Vector2(256.0, 256.0)


signal shards_changed(amount: float)

var memory_shards: float = 50.0:
	set(value):
		if is_equal_approx(memory_shards, value):
			return
		memory_shards = value
		shards_changed.emit(value)

#ui stuff
@onready var ui: PlayerUI = $UI
@onready var move_marker: Sprite3D = $MinimapContainer/SubViewportContainer/Minimap/MoveMarker

@export var player_id: int = 0

func _ready() -> void:
	set_active_squad(0)
	
	#Camera setup
	$"../NavigationRegion3D/Terrain3D".set_camera(camera)
	camera.global_transform = current_camera_mount.global_transform
	update_camera_target()
	
	#Signal setup
	ui.state_requested.connect(_on_state_requested)
	
	###connect to each squad's target marker and signals.
	for _squad:Squad in all_squads:
		connect_signals(_squad)

func connect_signals(_squad:Squad)->void:
	_squad.squad_terminated.connect(_on_squad_terminated)



func _input(event: InputEvent) -> void:
	# Squad-independent commands first.
	if event.is_action_pressed("next_squad"):  # Tab key or SWIPE_RIGHT
		cycle_next_squad()
		return
	elif event.is_action_pressed("previous_squad"):  # Shift+Tab or SWIPE_LEFT
		cycle_previous_squad()
		return
	
	# Everything below acts on the current squad.
	if not is_instance_valid(current_squad):
		return
	
	# Debug get a free unit spawn
	if event.is_action_pressed("debug_spawn_unit"):
		current_squad.add_unit()
	
	# Commands for current squad
	if event.is_action_pressed("target_command"):  # currently left click eventually TOUCH		and current_squad
		player_click_on_map()
	elif event.is_action_pressed("stop_command"):  # ... or ... 
		current_squad.stop_movement()


func _on_state_requested(new_state: GlobalEnums.WHEEL_SLOT) -> void:
	if not is_instance_valid(current_squad):
		return
	current_squad.state_machine.change_state(current_squad.state_machine.states.get(new_state))

## Mechanic. Instantiate a squad, place it, wire it, announce it.
func add_squad(scene: PackedScene, where: Vector3) -> Squad:
	var new_squad: Squad = scene.instantiate() as Squad
	if new_squad == null:
		return null
	add_child(new_squad)
	new_squad.global_position = where
	new_squad.controller = self
	new_squad.player_id = player_id
	connect_signals(new_squad)
	all_squads.append(new_squad)
	added_squad.emit(new_squad, all_squads.size() - 1, all_squads.size())
	return new_squad

##this player's bookkeeping: [br]Drop from all_squads, reassign current_squad, emit removed_squad. 
##[br]Can't know anything about other teams or the match.
func _on_squad_terminated(dead_squad: Squad) -> void:
	var i: int = all_squads.find(dead_squad)
	if i == -1:
		return
	all_squads.remove_at(i)
	removed_squad.emit(dead_squad, i, all_squads.size())
	if dead_squad == current_squad:
		current_squad = null
		if not all_squads.is_empty():
			set_active_squad(mini(i, all_squads.size() - 1))
	

const MAX_VISION_BONUS: int = 100

# rts_controller.gd — no accumulator, no signals to wire
func total_vision_bonus() -> float:
	var total: float = 0.0
	for squad: Squad in all_squads:
		total += squad.vision_contribution()
	return minf(total, MAX_VISION_BONUS)


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
	
	# Emit signal for UI updates
	swap_squad.emit(current_squad)
	
	_snap_next_frame = true 

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

func _camera_target_transform() -> Transform3D:
	var t: Transform3D = current_camera_mount.global_transform
	t.basis = t.basis.orthonormalized()          # strip the squad's scale
	var back: Vector3 = t.basis.z                    # +Z is behind the camera
	t.origin += back * total_vision_bonus()
	return t


##TODO hook up and also have when a building is lost, reduce the vision bonus. Also fog of war

### Visual feedback for move command
func enable_move_marker(position: Vector3) -> void:
	#var marker = move_marker.instantiate()
	#get_tree().current_scene.add_child(marker)
	
	move_marker.global_position = position
	move_marker.visible = true
	#marker.play_animation()  # Fade out over time
	







func _process(delta: float) -> void:
	if not is_instance_valid(current_squad) or not is_instance_valid(current_camera_mount):
		return
	var target: Transform3D = _camera_target_transform()
	if _snap_next_frame:
		camera.global_transform = target
		_snap_next_frame = false
		return
	var t: float = 1.0 - pow(0.005, delta)   # frame-rate independent smoothing
	camera.global_position = camera.global_position.lerp(target.origin, t)
	camera.quaternion = camera.quaternion.slerp(target.basis.get_rotation_quaternion(), t)
	
