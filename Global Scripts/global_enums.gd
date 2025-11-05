extends Node
class_name GlobalEnums

enum STATES 
{
READY, 			#stand and shoot anything that approaches  #### rename to READY
WARPATH, 		#Attack everything on the way to the target
TARGET, 		#Ignore everything else and move to attack the target
MARCH, 			#Just move, don't get distracted by attacking
SKIRMISH		#Attack while moving to stay at full range
}

enum ANIM_STATES {IDLE, MOVING, ATTACKING, DEAD}

enum DAMAGE_TYPE {LIGHT, MEDIUM, HEAVY}

enum ARMOR_TYPE {LIGHT, MEDIUM, HEAVY}
