extends Node
class_name Build

signal building_changed(build: Build, active: bool)

@export var parent:Squad
@export var type_of_upgrade:GlobalEnums.UPGRADE_TYPE

@export var duration: float = 30.0
var current_progress:float = 0.0

var is_building: bool = false:
	set(value):
		if is_building == value:
			return
		is_building = value
		building_changed.emit(self, value)

@export var cost: int = 0    ## Total shards at normal efficiency. 0 = use the squad's price.

func total_cost() -> float:
	if cost > 0:
		return float(cost)
	return parent.price_of(type_of_upgrade)

@export var repeatable:bool = false

@export var squad_type_to_buy:PackedScene = preload("res://Models/squad.tscn")
@export var weapon_to_grant: PackedScene

func _ready() -> void:
	if !parent:
		parent = get_parent() as Squad

###Connect the upgrade type to squad function or squad signals to controller
func complete()->bool:
	match type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			return parent.add_unit()
			
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD:
			return parent.add_squad(squad_type_to_buy)
		GlobalEnums.UPGRADE_TYPE.GET_WEAPON:
			return parent.grant_weapon(weapon_to_grant)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_WEAPON:
		#GlobalEnums.UPGRADE_TYPE.BUY_AMMO:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_HEALTH:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_ARMOR:
		_:
			push_warning("Build %s has no completion handler" % self)
			return false


##The efficiency knob is the ratio cost_multiplier ÷ speed_multiplier, not either export alone.
func check_build(delta:float, speed_multiplier:float, cost_multiplier:float = 1.0) -> bool:
	if parent.controller == null or not is_building:
		return false
	
	var work: float = minf(delta * speed_multiplier, duration - current_progress)
	if work <= 0.0:
		return false
	
	##Spending
	#one line instead of three, and no knowledge of controllers
	var spend: float = (total_cost() / duration) * work * (cost_multiplier / speed_multiplier)
	if not parent.try_spend(spend):
		return false                       # stall this frame, don't charge
	current_progress += work
	
	if current_progress >= duration:
		if complete():                # make complete() return bool
			current_progress = 0.0
			if not repeatable:
				is_building = false
		else:
			current_progress = duration   # hold at full, stop billing
			is_building = false          # and tell the player why
	return true





func _to_string() -> String:
	match type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			return "Buy a Unit"
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD:
			return "Buy a Squad"
		#GlobalEnums.UPGRADE_TYPE.GET_WEAPON:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_WEAPON:
		#GlobalEnums.UPGRADE_TYPE.BUY_AMMO:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_HEALTH:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_ARMOR:
		_:
			return ("connecting to build went wrong")
