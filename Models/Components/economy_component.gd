class_name EconomyComponent
extends Node
## The buy_ layer: what this squad can purchase, what it costs, and whether the
## player may start it. Build nodes own the timed construction; RosterComponent
## owns making the thing exist. Three questions, three owners:
##
##   buy_…()   Should this happen?      Costs, caps, refusing with a reason.
##   Build     Is it happening yet?     Progress, per-frame spend, cancellation.
##   add_…()   Can this exist? Make it. Preconditions and instantiation.


#region ────────────────────────────  constants  ─────────────────────────────

## Why a purchase was refused. The UI turns these into words; this component
## deliberately knows nothing about toasts.
enum PurchaseResult { OK, SQUAD_FULL, NO_SUCH_BUILD, ALREADY_BUILDING, NO_PURSE }

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Wiring")
@export var stats: SquadStats

@export_group("Catalogue")
## Everything this squad can build. One Build node per purchasable thing.
@export var upgrades: Array[Build] = []
## TODO unread. Build carries its own weapon_to_grant, which is the one
## complete() actually uses — decide whether this is the squad-type default
## for GET_WEAPON, or delete it as a duplicate.
@export var weapon_to_grant: PackedScene
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

var _squad: Squad

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	_squad = get_parent() as Squad


#region prices

#endregion


#region ──────────────────────────────  prices  ──────────────────────────────

func price_of(upgrade: GlobalEnums.UPGRADE_TYPE) -> float:
	match upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:  return float(stats.unit_cost)
		GlobalEnums.UPGRADE_TYPE.BUY_SQUAD: return float(stats.squad_cost)
		_:                                  return 0.0

## Spend from the owner's purse. A neutral owner carries none, so a wild squad
## cannot afford anything, which is the correct answer for it.
func try_spend(amount: float) -> bool:
	var purse: RTSController = _purse()
	if purse == null or purse.memory_shards < amount:
		return false
	purse.memory_shards -= amount
	return true

## Whose purse pays for this squad, or null if its owner has none. Only a
## player's controller carries one today. The plan moves the purse to the team
## and to building stockpiles — when it does, this is the line that changes.
func _purse() -> RTSController:
	return _squad.controller as RTSController

#endregion


#region what is queued

#endregion


#region ──────────────────────────  what is queued  ──────────────────────────

func find_build(type: GlobalEnums.UPGRADE_TYPE) -> Build:
	for upgrade: Build in upgrades:
		if upgrade.type_of_upgrade == type:
			return upgrade
	return null

func is_building_anything() -> bool:
	for upgrade: Build in upgrades:
		if upgrade.is_building:
			return true
	return false

## Everything currently under construction, for a per-squad progress panel.
func get_active_builds() -> Array[Build]:
	var active: Array[Build] = []
	for upgrade: Build in upgrades:
		if upgrade.is_building:
			active.append(upgrade)
	return active

#endregion


#region purchases

#endregion


#region ────────────────────────────  purchases  ─────────────────────────────

## Player-facing. May this build start? If so, start it. Every gate for every
## upgrade type lives here, in one place, and refuses with a reason the UI can
## show rather than a bare false.
func request_build(build: Build) -> PurchaseResult:
	if _purse() == null:
		return PurchaseResult.NO_PURSE
	if build.is_building:
		return PurchaseResult.ALREADY_BUILDING
	match build.type_of_upgrade:
		GlobalEnums.UPGRADE_TYPE.BUY_UNIT:
			if not _squad.roster.has_room():
				return PurchaseResult.SQUAD_FULL
		# future types add their own gates here
	build.is_building = true
	return PurchaseResult.OK

## Player-facing. Starts a recruit; does not spend (Build drains over time).
func buy_unit() -> PurchaseResult:
	var build: Build = find_build(GlobalEnums.UPGRADE_TYPE.BUY_UNIT)
	if build == null:
		return PurchaseResult.NO_SUCH_BUILD
	return request_build(build)

func buy_squad(scene: PackedScene) -> bool:
	return _squad.controller.add_squad(scene, spawn_position()) != null

#endregion

## In FRONT of this squad, not at a fixed world offset — so a bought squad
## appears out of the barracks door rather than always to world -Z.
func spawn_position() -> Vector3:
	return _squad.global_position - _squad.global_transform.basis.z * stats.squad_spawn_distance

#endregion
