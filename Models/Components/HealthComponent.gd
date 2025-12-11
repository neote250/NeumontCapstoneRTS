extends Node
class_name HealthComponent

#signals
signal died(dead_unit: Unit)

@export var Max_Health: int = 100
var health: int

@export var health_bar:HealthBar

func _ready() -> void:
	health = Max_Health
	health_bar.init_health(health)

###Take damage at the lowest level, where it actually happens
func take_damage(attack: Attack) -> void:
	health -= attack.attack_damage
	if health <= 0:
		emit_signal("died", get_parent()) #signal to squad which unit died / was self, but that just emits the component node
	health_bar.health = health
