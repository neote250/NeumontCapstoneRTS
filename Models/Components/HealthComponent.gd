extends Node
class_name HealthComponent

#signals
signal died(dead_unit: Unit)


@export var Max_Health: int = 100
var health: int


func _ready() -> void:
	health = Max_Health

###Take damage at the lowest level, where it actually happens
func take_damage(attack: Attack) -> void:
	health -= attack.attack_damage
	if health <= 0:
		emit_signal("died", get_parent()) #signal to squad which unit died / was self, but that just emits the component node
