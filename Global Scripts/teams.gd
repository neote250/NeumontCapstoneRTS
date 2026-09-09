extends RefCounted
class_name Teams

const NEUTRAL: int = -1

## Global toggle — flip for a "friendly fire on" match rule.
static var friendly_fire: bool = false

## 	May A attack B? — used by targeting and the damage guard
static func is_hostile(attacker_id: int, target_id: int) -> bool:
	if attacker_id == target_id:
		return friendly_fire          # same team
	if attacker_id == NEUTRAL and target_id == NEUTRAL:
		return false                  # neutrals ignore each other
	return true
