extends Controller
class_name NeutralController
## Owns the wild squads: a player who never presses anything. No camera, no
## input, no UI, no purse — only a roster, so a wild squad follows the same
## ownership rules as every other squad instead of being a special case.


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	# Neutral, on no team, is the one thing this node is. A wrong Player Id
	# would quietly ally the wild squads with that player, and a Team Id would
	# be silently ignored, so name either mistake instead.
	if player_id != Teams.NEUTRAL:
		push_error("%s has Player Id %d — a NeutralController must be %d." % [name, player_id, Teams.NEUTRAL])
	if team_id != Teams.NO_TEAM:
		push_error("%s has Team Id %d — a NeutralController is on no team." % [name, team_id])
	super()

#endregion
