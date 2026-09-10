class_name MovementComponent
extends Node
## Navigation and steering for the squad body. Owns velocity x and z;
## y belongs to gravity and Ground.snap().
##
## There is deliberately no `destination` field here — nav_agent.target_position
## already is one, and a second copy is the drift this project keeps deleting.

@export var stats: SquadStats
@export var nav_agent: NavigationAgent3D

var _squad: Squad
var _ground_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_squad = get_parent() as Squad


func set_destination(where: Vector3) -> void:
	nav_agent.target_position = where


func is_arrived() -> bool:
	return nav_agent.is_navigation_finished()


## Halt where we stand. Clearing the target is Squad's call, not ours.
func stop() -> void:
	nav_agent.target_position = _squad.global_position
	_squad.velocity = Vector3.ZERO


## Step along the nav path. Returns false once the destination is reached, so
## each state decides for itself what "arrived" means.
func advance(delta: float) -> bool:
	if nav_agent.is_navigation_finished():
		return false
	step(delta)
	return true


## One physics frame of steering toward the next path point, facing that way.
## TODO delta is unused: turn_smoothing is applied per frame, so acceleration
## is frame-rate dependent. rts_controller solves this for the camera with
## 1.0 - pow(factor, delta) — the same treatment belongs here.
func step(_delta: float) -> void:
	var next_point: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = (next_point - _squad.global_position).normalized()
	direction.y = 0.0

	# Face the way we are going, easing rather than snapping.
	var facing: Vector3 = -_squad.global_transform.basis.z
	var new_facing: Vector3 = facing.slerp(direction, stats.turn_smoothing).normalized()
	_squad.look_at(_squad.global_position + new_facing, Vector3.UP)

	var desired: Vector3 = direction * stats.speed
	_squad.velocity.x = lerp(_squad.velocity.x, desired.x, stats.turn_smoothing)
	_squad.velocity.z = lerp(_squad.velocity.z, desired.z, stats.turn_smoothing)
	_squad.move_and_slide()


func snap_to_ground() -> void:
	Ground.snap(_squad, _ground_query)
