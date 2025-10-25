extends Node
class_name HealthComponent

#signals
signal died(Unit)


@export var Max_Health:= 100
var health : int


func _ready() -> void:
	health = Max_Health


func damage(attack: Attack):
	health -= attack.attack_damage
	if health <= 0:
		emit_signal("died", self)
		get_parent().queue_free()
