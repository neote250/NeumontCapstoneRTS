extends Node
class_name GlobalEnums

enum STATES 
{
CENTER, 			#stand and shoot anything that approaches
UP, 		#Attack everything on the way to the target
LEFT, 		#Ignore everything else and move to attack the target
DOWN, 			#Just move, don't get distracted by attacking
RIGHT		#Attack while moving to stay at full range
}

enum UPGRADE_TYPE
{
	BUY_UNIT, 
	BUY_SQUAD, 
	GET_WEAPON, 
	UPGRADE_WEAPON, 
	BUY_AMMO, 
	UPGRADE_HEALTH, 
	UPGRADE_ARMOR
}


enum ANIM_STATES {IDLE, MOVING, ATTACKING, DEAD}

enum DAMAGE_TYPE {LIGHT, MEDIUM, HEAVY}

enum ARMOR_TYPE {LIGHT, MEDIUM, HEAVY}
