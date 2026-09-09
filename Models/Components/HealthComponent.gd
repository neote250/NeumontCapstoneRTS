extends Node
class_name HealthComponent

#signals
signal died(dead_unit: Unit)

@export var max_health: int = 100
var health: int

@export var health_bar:HealthBar
@export var armor_type: GlobalEnums.ARMOR_TYPE

func _ready() -> void:
	health = max_health
	if health_bar == null:
		return
	health_bar.init_health(health)

##Take damage at the lowest level, where it actually happens [br] Subtract, update the bar, announce death
func apply_damage(amount:int) -> void:
	health -= amount
	if health_bar:
		health_bar.health = health
	if health <= 0:
		died.emit(get_parent() as Unit) #signal to squad which unit died
