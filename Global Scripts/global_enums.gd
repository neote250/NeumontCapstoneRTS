extends RefCounted
class_name GlobalEnums

enum WHEEL_SLOT 
{
DEFAULT, 
AGGRESSIVE, 
FOCUS, 
MOVE, 
ECONOMY
}

##For a generic unit
#stand and shoot anything that approaches
#Attack everything on the way to the target
#Ignore everything else and move to attack the target
#Just move, don't get distracted by attacking
#Attack while moving to stay at full range

##For a generic building
#build mode
#turret mode?
#overcharge?
#
#

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

enum STANCE
{
	HOLD_FIRE, # Nothing. Stay hidden, save ammo, avoid pulling a fight.
	RETURN_FIRE, # Only what has damaged you recently. Passive, no repositioning.
	WEAPONS_FREE # Anything hostile in range, proactively.
}

enum ANIM_STATES {IDLE, MOVING, ATTACKING, DEAD}

enum DAMAGE_TYPE {LIGHT, MEDIUM, HEAVY}

enum ARMOR_TYPE {LIGHT, MEDIUM, HEAVY}
