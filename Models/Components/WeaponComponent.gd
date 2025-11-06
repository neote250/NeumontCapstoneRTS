extends Node
class_name WeaponComponent

#signal
signal deal_damage(unit_attack:Attack)

@export var AttackOptions: Array[Attack] = []
var CurrentAttack: Attack
var CurrentAttackIndex:int = 0
var cooldown_from_attack: float = 0

func _ready() -> void:
	if AttackOptions.size() > 0:
		CurrentAttack = AttackOptions[0]

func damage_target(delta:float) -> void:
	if cooldown_from_attack > CurrentAttack.attack_speed:
		deal_damage.emit(CurrentAttack)
		cooldown_from_attack -= CurrentAttack.attack_speed
	else:
		cooldown_from_attack += delta


func swap_weapon() -> void:
	if AttackOptions.size()>1:
		CurrentAttackIndex = (CurrentAttackIndex + 1) % AttackOptions.size()
		CurrentAttack = AttackOptions[CurrentAttackIndex]
