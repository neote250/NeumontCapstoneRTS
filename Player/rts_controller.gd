extends Controller
class_name RTSController
## One player's hands: input, camera, which squad is selected, and the purse.
## The roster itself is Controller's; this adds what only a person needs.
## Does this player's bookkeeping only — anything spanning players belongs to
## the GameManager.


#region ─────────────────────────────  signals  ──────────────────────────────

## The selected squad changed. The UI repopulates from this.
signal swap_squad(new_squad: Squad)
signal shards_changed(amount: float)

#endregion


#region ────────────────────────────  constants  ─────────────────────────────

## Ceiling on how far buildings can push the camera back.
const MAX_VISION_BONUS: int = 100

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Wiring")
## The place this player is playing on. Read for its terrain, which needs a
## camera to choose its level of detail.
## TODO stage 3c, then review whether this export should exist at all. Once
## the match builds this player it can call map.terrain.set_camera() itself,
## right after add_child(), and nothing here would need the map — unless the
## minimap wants the map's bounds by then. The minimap camera is still
## hardcoded to this map's centre, which is the thing to look at when deciding.
@export var map: Map
@export_group("")

#endregion


#region ─────────────────────────  node references  ──────────────────────────

@onready var camera: Camera3D = $Camera3D
@onready var ui: PlayerUI = $UI
@onready var minimap: SubViewport = $MinimapContainer/SubViewportContainer/Minimap
@onready var minimap_camera: Camera3D = $MinimapContainer/SubViewportContainer/Minimap/Camera3D
@onready var move_marker: Sprite3D = $MinimapContainer/SubViewportContainer/Minimap/MoveMarker
@onready var current_camera_mount: Node3D

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

var current_squad: Squad = null
## Derived, never stored. The stored copy went stale whenever a squad ahead of
## the selected one died. -1 when nothing is selected.
var current_squad_index: int:
	get:
		return all_squads.find(current_squad)
	set(_value):
		push_error("current_squad_index is derived from current_squad. Use set_active_squad().")
## TODO never written. Quick-swap-to-previous needs set_active_squad() to
## record where it came from — see the plan's section on placeholders. Store
## the Squad rather than its index when it is built: indices shift on a death.
var last_squad_index: int = -1

## Cut to the new squad rather than easing, for one frame after a swap.
var _snap_next_frame: bool = true

## TODO unread. Presumably minimap bounds.
var map_coordinates: Vector2 = Vector2(256.0, 256.0)

## The purse. The setter is the only place a change is announced, so nothing
## can spend silently.
var memory_shards: float = 50.0:
	set(value):
		if is_equal_approx(memory_shards, value):
			return
		memory_shards = value
		shards_changed.emit(value)

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

## Camera and signal wiring only. Nothing here depends on owning a squad:
## this player is built before it has any, and the match hands them over.
func _ready() -> void:
	# Terrain3D picks its level of detail from a camera, and this is the only
	# controller that has one. Asked of the map rather than found by a path
	# through it, so this scene can be spawned on any map.
	map.terrain.set_camera(camera)
	ui.state_requested.connect(_on_state_requested)
	super()   # Controller: collect any squads the map placed for this player

	# An empty roster is the normal state here — stage 0's guard is gone with
	# the hand-placed squads it was guarding. The match spawns this player's
	# starting group and then calls set_active_squad(), which is also what
	# points the camera; _snap_next_frame has _process() cut to it on the
	# first frame after that.
	#
	# That later set_active_squad() still reads the squad's @onready
	# camera_mount, so the squads must be ready when the match calls it. The
	# rule that used to live here — "the Squads container has to sit above this
	# node" — did not go away with stage 3c; it moved to the node that now does
	# the spawning. Controller.add_squad() enforces it.

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
		current_squad.roster.add_unit()
	
	# Commands for current squad
	if event.is_action_pressed("target_command"):  # currently left click eventually TOUCH		and current_squad
		player_click_on_map()
	elif event.is_action_pressed("stop_command"):  # ... or ... 
		current_squad.stop_movement()

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
	

#endregion


#region ─────────────────────────  squad selection  ──────────────────────────

## Select by position in all_squads. Range-checked so it is safe to call from
## anywhere — the cycle functions guard themselves, but quick-swap will not.
func set_active_squad(index: int) -> void:
	if index < 0 or index >= all_squads.size():
		push_error("set_active_squad(%d) out of range — %d squads." % [index, all_squads.size()])
		return

	# Set new active squad — current_squad_index follows from it
	current_squad = all_squads[index]
	
	# Update camera to follow new squad
	current_camera_mount = current_squad.camera_mount
	update_camera_target()
	
	# Emit signal for UI updates
	swap_squad.emit(current_squad)
	
	_snap_next_frame = true 

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

## Roster bookkeeping first (Controller), then the one thing only a player has:
## a selection.
func _on_squad_terminated(dead_squad: Squad) -> void:
	var slot: int = current_squad_index        # read before the roster shrinks
	super(dead_squad)
	_reselect_after(dead_squad, slot)

## Giving away the squad you are looking at needs the same fix-up as losing it,
## or the camera stays on a squad that is no longer yours. Hence the shared
## method rather than the same four lines twice.
func release(squad: Squad) -> void:
	var slot: int = current_squad_index
	super(squad)
	_reselect_after(squad, slot)

## The squad at `slot` has just left the roster. If it was the selected one,
## select whichever squad slid into its place, or the new last one. Silent when
## the roster is now empty: that is spectate mode, not an error.
func _reselect_after(lost: Squad, slot: int) -> void:
	if lost != current_squad:
		return
	current_squad = null
	if not all_squads.is_empty():
		set_active_squad(mini(slot, all_squads.size() - 1))

## The round is over. The match tells the local player, and the player tells
## its own UI — the UI's only channel upward is state_requested, so nothing
## below reaches past it.
##
## Input stops; the camera does not, so the final state stays watchable behind
## the banner. Squads do keep fighting: a real freeze is get_tree().paused, and
## every squad scene is PROCESS_MODE_ALWAYS, so that is a pass over process
## modes rather than one line here.
func end_match(winning_team: int) -> void:
	set_process_input(false)
	ui.show_result(winning_team, winning_team == team_id)

#endregion


#region ──────────────────────────────  orders  ──────────────────────────────

func _on_state_requested(new_state: GlobalEnums.WHEEL_SLOT) -> void:
	if not is_instance_valid(current_squad):
		return
	current_squad.state_machine.change_state(current_squad.state_machine.states.get(new_state))

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
		current_squad.movement.set_destination(result.position)
		###DEBUG
		ui.change_testing_data_text(result.position)
	else: return
	
	# Add visual feedback at target position
	enable_move_marker(result.position)

###Handle result of a finger press on map
func player_press_on_map() -> void:
	pass






###VISUALS

#endregion


#region ──────────────────────────────  camera  ──────────────────────────────

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

# rts_controller.gd — no accumulator, no signals to wire
func total_vision_bonus() -> float:
	var total: float = 0.0
	for squad: Squad in all_squads:
		total += squad.vision_contribution()
	return minf(total, MAX_VISION_BONUS)

#endregion


#region ───────────────────────  minimap and markers  ────────────────────────

### Visual feedback for move command
func enable_move_marker(position: Vector3) -> void:
	#var marker = move_marker.instantiate()
	#get_tree().current_scene.add_child(marker)
	
	move_marker.global_position = position
	move_marker.visible = true
	#marker.play_animation()  # Fade out over time
	

###Option for player to increase minimap size on LONG press or SHIFT
func increase_minimap_scale() -> void:
	pass

#endregion
