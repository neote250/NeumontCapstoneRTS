extends RefCounted
class_name Teams
## The rules for who fights whom. Static, and no nodes: the one piece of state
## is the player → team lookup the match fills once at startup.


#region ────────────────────────────  constants  ─────────────────────────────

## player_id of the NeutralController, and so of every wild squad.
const NEUTRAL: int = -1
## team_id of a controller on no team. Only the NeutralController.
const NO_TEAM: int = -1

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## Keep false for now. is_hostile() answers both "pick this as a target?" and
## "does this hit count?", so switching it on would have teammates hunt each
## other. Friendly fire needs those two questions split first.
static var friendly_fire: bool = false

## player_id → team id. Flat because it is read on every targeting scan.
## Written only by set_roster().
static var _team_of: Dictionary[int, int] = {}

#endregion


#region ──────────────────────────────  roster  ──────────────────────────────

## Replace the lookup with the match's. Cleared first: static state outlives a
## scene reload, so a restarted match would otherwise keep the old sides.
## Takes plain ids, so these rules never depend on Team or Controller.
static func set_roster(team_of: Dictionary[int, int]) -> void:
	_team_of.clear()
	_team_of.merge(team_of)

#endregion


#region ────────────────────────────  hostility  ─────────────────────────────

## May A attack B? Used by targeting, clicks, and the damage guard.
## No fallback for a player missing from the lookup: a guessed team can collide
## with a real one, and the GameManager already named any unassigned player.
static func is_hostile(attacker_id: int, target_id: int) -> bool:
	if attacker_id == NEUTRAL or target_id == NEUTRAL:
		return attacker_id != target_id      # neutrals fight everyone but each other
	if _team_of[attacker_id] == _team_of[target_id]:
		return friendly_fire                 # same side
	return true

#endregion
