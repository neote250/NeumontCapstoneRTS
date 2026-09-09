extends Node
class_name WeaponComponent

#signal
signal deal_damage(unit_attack:Attack)

@export var attack_options: Array[Attack] = []
var current_attack: Attack
var current_attack_index:int = 0
var cooldown_from_attack: float = 0

func _ready() -> void:
	if attack_options.size() > 0:
		current_attack = attack_options[0]

func damage_target(delta:float) -> void:
	if current_attack == null:
		return
	if cooldown_from_attack > current_attack.attack_speed:
		deal_damage.emit(current_attack)
		cooldown_from_attack -= current_attack.attack_speed
	else:
		cooldown_from_attack += delta

func can_fire() -> bool:
	return current_attack != null

func swap_weapon() -> void:
	if attack_options.size()>1:
		current_attack_index = (current_attack_index + 1) % attack_options.size()
		current_attack = attack_options[current_attack_index]
