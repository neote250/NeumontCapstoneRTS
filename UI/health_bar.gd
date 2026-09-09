extends ProgressBar
class_name  HealthBar
#@onready var health_bar: ProgressBar = $"."


var health:float = 0:
	set(new_health):
		#var prev_health = health
		health = min(max_value, new_health)
		value = health

func init_health(_health:float) -> void:
	max_value = _health
	min_value = 0.0
	health = _health

#func _ready() -> void:
	#show_percentage = false
