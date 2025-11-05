extends ProgressBar
@onready var health_bar: ProgressBar = $"."


var health:int = 0:
	set(new_health):
		var prev_health = health
		health = min(max_value, new_health)
		value = health

func init_health(_health):
	health = _health
	max_value = health
	value = health
