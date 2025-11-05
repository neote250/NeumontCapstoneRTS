extends State
class_name AiIdleState

@export var ai_squad: Squad
@export var idle_move_speed: float = 10.0

var move_direction: Vector3
var wander_time: float

func randomize_wander():
	move_direction = Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized()
	wander_time = randf_range(1,3)

func Enter():
	randomize_wander()

func State_Update(delta: float):
	if wander_time > 0:
		wander_time -= delta
	
	else:
		randomize_wander()

func State_Physics_Update(delta: float):
	if ai_squad:
		ai_squad.velocity = move_direction * idle_move_speed
