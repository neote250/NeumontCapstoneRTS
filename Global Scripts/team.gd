extends RefCounted
class_name Team
## One side of the match: which players are on it, and the state that belongs
## to the side rather than to any one player. Built by the GameManager at
## startup. Hostility checks read Teams' flat lookup, not this, so the damage
## path never walks a list.


#region ──────────────────────────────  state  ───────────────────────────────

var id: int
## The players on this side. Controllers rather than player ids, so a question
## like "does anyone on this team still own a squad?" can be asked directly.
var members: Array[Controller] = []

## PLACEHOLDER: the team's shared basic currency. Nothing reads it yet; the
## purse is still RTSController.memory_shards, reached only through
## EconomyComponent._purse(). See the plan, "The purse does not belong to the
## player".
var pooled: float = 0.0
## Nothing left at all, buildings included. Maintained by the match whenever a
## squad dies, and read by the Elimination condition. Terminal: a side with
## nothing has nobody left to be handed a squad by.
##
## A *player* with no squads is spectating, not eliminated — that is a
## different question, asked of one controller rather than of the side.
var eliminated: bool = false
# TODO buffs granted at crystals: add Array[TeamBuff] once TeamBuff is designed
# (the plan, section 06, "Crystal mechanics").

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _init(team_id: int) -> void:
	id = team_id

#endregion


#region ─────────────────────────────  queries  ──────────────────────────────

## Does anyone on this side still own a squad? The reason members holds
## Controllers rather than player ids: the answer is one hop away instead of a
## lookup through the match.
func holds_squads() -> bool:
	for member: Controller in members:
		if not member.all_squads.is_empty():
			return true
	return false

#endregion
