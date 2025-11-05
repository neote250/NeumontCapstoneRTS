extends Node
class_name WeaponComponent

#signal
signal deal_damage(target)

@export var AttackOptions: Array[Attack] = []
var CurrentAttack: Attack
var CurrentAttackIndex = 0
var cooldown_from_attack: float = 0

#var is_damage_positively_modified: bool = false
#var is_damage_negatively_modified: bool = false
#var current_positive_modifier: float
#var current_negative_modifier: float
#var current_positive_mod_timer: float
#var current_negative_mod_timer: float
		#if modifier > 0:
			#is_damage_positively_modified = true
			##do check if current positive modifer is less than new positive modifier
		#elif modifier < 0:
			#is_damage_negatively_modified = true
			##do check if current negative modifer is less than new negative modifier
		#elif modifier == 0:
			#return
		#
		#if is_damage_negatively_modified:
			#damage = damage - (base_damage * modifier)
		#if is_damage_positively_modified:
			#damage = damage + (base_damage * modifier)

var target_unit: Unit


func _ready() -> void:
	if AttackOptions.size() > 0:
		CurrentAttack = AttackOptions[0]

func damage_target(delta:float) -> void:
	if cooldown_from_attack > CurrentAttack.attack_speed:
		target_unit.damage(CurrentAttack)
		cooldown_from_attack -= CurrentAttack.attack_speed
	else:
		cooldown_from_attack += delta


func swap_weapon() -> void:
	if AttackOptions.size()>1:
		CurrentAttackIndex = (CurrentAttackIndex + 1) % AttackOptions.size()
		CurrentAttack = AttackOptions[CurrentAttackIndex]
