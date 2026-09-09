extends RefCounted
class_name Combat ##This class handles combat calculations?

## damage_type → armor_type → multiplier
const TYPE_CHART: Dictionary = {
	GlobalEnums.DAMAGE_TYPE.LIGHT:  {        
		GlobalEnums.ARMOR_TYPE.LIGHT:  1.00,
		GlobalEnums.ARMOR_TYPE.MEDIUM: 0.75,
		GlobalEnums.ARMOR_TYPE.HEAVY:  0.50,
		},
	GlobalEnums.DAMAGE_TYPE.MEDIUM: {
		GlobalEnums.ARMOR_TYPE.LIGHT:  0.75,
		GlobalEnums.ARMOR_TYPE.MEDIUM: 1.00,
		GlobalEnums.ARMOR_TYPE.HEAVY:  0.75,
		},
	GlobalEnums.DAMAGE_TYPE.HEAVY:  {
		GlobalEnums.ARMOR_TYPE.LIGHT:  0.50,
		GlobalEnums.ARMOR_TYPE.MEDIUM: 0.75,
		GlobalEnums.ARMOR_TYPE.HEAVY:  1.00,
		},
}

## How much damage this attack deals to this armour class.  [br]How much does it hurt, given armour?
static func resolve(attack: Attack, armor: GlobalEnums.ARMOR_TYPE) -> int:
	var mult: float = TYPE_CHART[attack.damage_type][armor]
	return maxi(1, roundi(attack.attack_damage * mult))
