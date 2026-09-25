extends Node
class_name Build
## One purchasable thing, and the timed construction of it. This is the middle
## of the three purchase layers:
##
##   EconomyComponent.buy_…()  Should this happen?   Costs, caps, refusals.
##   Build (this)              Is it happening yet?  Progress and per-frame spend.
##   RosterComponent.add_…()   Can it exist? Make it.
##
## Construction is a node rather than a method because it holds state — how far
## along, whether it is running, what multipliers apply. Functions do not.


#region ─────────────────────────────  signals  ──────────────────────────────

## Toggled on or off. The UI listens so a squad row can show what is building.
signal building_changed(build: Build, active: bool)

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Wiring")
## The squad that pays for and receives this. Set by NodePath in every scene.
## TODO the fallback in _ready() walks one level, but Builds now sit under
## EconomyComponent — get_owner() would be correct, or delete it entirely.
@export var parent: Squad
@export var type_of_upgrade: GlobalEnums.UPGRADE_TYPE

@export_group("Cost and Time")
@export var duration: float = 30.0
## Total shards at normal efficiency. 0 = use the squad type's price.
@export var cost: int = 0
## Whether the build restarts itself on completion.
@export var repeatable: bool = false

@export_group("What It Makes")
@export var squad_type_to_buy: PackedScene = preload("uid://1cmfjqxuuyw1")
@export var weapon_to_grant: PackedScene
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

var current_progress: float = 0.0

## Setting this is how a build starts and stops. The setter is the single
## place the change is announced, so nothing can toggle it silently.
var is_building: bool = false:
	set(value):
		if is_building == value:
			return
		is_building = value
		building_changed.emit(self, value)

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	if !parent:
		parent = get_owner() as Squad

#endregion


#region ─────────────────────────────  pricing  ──────────────────────────────

func total_cost() -> float:
	if cost > 0:
		return float(cost)
	return parent.economy.price_of(type_of_upgrade)



#endregion


#region ───────────────────────────  construction  ───────────────────────────

##The efficiency knob is the ratio cost_multiplier ÷ speed_multiplier, not either export alone.
func check_build(delta:float, speed_multiplier:float, cost_multiplier:float = 1.0) -> bool:
	if not is_building:
		return false
	
	var work: float = minf(delta * speed_multiplier, duration - current_progress)
	if work <= 0.0:
		return false
	
	##Spending
	#one line instead of three, and no knowledge of controllers
	var spend: float = (total_cost() / duration) * work * (cost_multiplier / speed_multiplier)
	if not parent.economy.try_spend(spend):
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

###Connect the upgrade type to squad function or squad signals to controller
func complete()->bool:
	match type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			return parent.roster.add_unit()
			
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD:
			return parent.economy.buy_squad(squad_type_to_buy)
		GlobalEnums.UPGRADE_TYPE.GET_WEAPON:
			return parent.roster.grant_weapon(weapon_to_grant)
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_WEAPON:
		#GlobalEnums.UPGRADE_TYPE.BUY_AMMO:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_HEALTH:
		#GlobalEnums.UPGRADE_TYPE.UPGRADE_ARMOR:
		_:
			push_warning("Build %s has no completion handler" % self)
			return false

#endregion


#region ─────────────────────────────  display  ──────────────────────────────

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

#endregion
