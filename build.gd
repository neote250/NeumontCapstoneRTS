extends Node
class_name Build

@export var parent:Squad
@export var type_of_upgrade:GlobalEnums.UPGRADE_TYPE

@export var duration: float = 30.0
var current_progress:float = 0.0
var is_building:bool = false

@export var cost: int = 20

@export var repeatable:bool = false

@export var squad_type_to_buy:PackedScene = preload("res://Models/squad.tscn")
#var weapon_type_to_buy

func _ready() -> void:
	if !parent:
		parent = get_parent() as Squad

###Connect the upgrade type to squad function or squad signals to controller
func complete()->void:
	match type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			parent.add_unit()
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD:
			buy_squad()
		#GlobalEnums.UPGRADE_TYPE.GET_WEAPON:
			#_upgrade.completed.connect(get_weapon)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_WEAPON:
			#_upgrade.completed.connect(upgrade_weapon)
		#GlobalEnums.UPGRADE_TYPE.BUY_AMMO:
			#_upgrade.completed.connect(buy_ammo)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_HEALTH:
			#_upgrade.completed.connect(upgrade_health)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_ARMOR:
			#_upgrade.completed.connect(upgrade_armor)
		_:
			print("connecting to build went wrong")
	return


func get_weapon():
	pass

func upgrade_weapon():
	pass

func buy_ammo():
	pass

func upgrade_health():
	pass

func upgrade_armor():
	pass

##Any logic on the squad itself when the upgrade to buy a squad completes.
##For example limited buys, like you pick up the building kit at the base
func buy_squad() -> void:
	parent.Controller_Add_Squad.emit(parent.global_position, squad_type_to_buy)

##
func check_build(_progress:float, cost:float, multiplier:float) -> void:
	#parent.RTS_Controller_Check_Progress.emit(parent, _delta, cost)
	if parent.controller.memory_shards > cost * _progress:
		parent.controller.memory_shards -= _progress * cost
		current_progress += _progress * multiplier
		#if parent.controller.ui.build_dict.has(self):
		if current_progress >= duration:
			current_progress = 0
			complete()

func _to_string() -> String:
	match type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			return "Buy a Unit"
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD:
			return "Buy a Squad"
		#GlobalEnums.UPGRADE_TYPE.GET_WEAPON:
			#_upgrade.completed.connect(get_weapon)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_WEAPON:
			#_upgrade.completed.connect(upgrade_weapon)
		#GlobalEnums.UPGRADE_TYPE.BUY_AMMO:
			#_upgrade.completed.connect(buy_ammo)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_HEALTH:
			#_upgrade.completed.connect(upgrade_health)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_ARMOR:
			#_upgrade.completed.connect(upgrade_armor)
		_:
			return ("connecting to build went wrong")
