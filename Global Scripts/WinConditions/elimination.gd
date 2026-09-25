extends WinCondition
class_name Elimination
## The last side still holding anything wins. Buildings count, because a
## building is a squad — so a team reduced to its base is alive, and with
## income it can rebuild. That is why this is not the only condition in a
## standard round: without a clock, two turtled teams never finish.


#region ─────────────────────────────  the rule  ─────────────────────────────

## Reads Team.eliminated rather than recounting squads. The match maintains
## that flag when a squad dies, which is the one place that knows a roster
## just changed.
func check(m: MatchManager) -> int:
	var survivor: int = Teams.NO_TEAM
	var alive: int = 0
	for team: Team in m.teams:
		if team.eliminated:
			continue
		survivor = team.id
		alive += 1
	if alive == 1:
		return survivor
	# 0 is a mutual wipe — both last squads died in the same frame. Nobody
	# earned it, so the round runs on and the clock settles it.
	return Teams.NO_TEAM

#endregion
