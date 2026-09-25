extends State
class_name AiIdleState

##TODO this state still needs a lot of work

@export var ai_squad: Squad
@export var idle_move_speed: float = 10.0

var move_direction: Vector3
var wander_time: float

func randomize_wander():
	move_direction = Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized()
	wander_time = randf_range(1,3)

func enter():
	super()
	randomize_wander()

func state_update(delta: float) -> State:
	if wander_time > 0:
		wander_time -= delta
	
	else:
		randomize_wander()
	return null

func state_physics_update(delta: float) -> State:
	if ai_squad:
		ai_squad.velocity = move_direction * idle_move_speed
	return null
