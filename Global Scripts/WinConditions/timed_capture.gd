extends WinCondition
class_name TimedCapture
## The clock. When it runs out the team holding the most crystals wins.
##
## A tie is not broken here. The clock exists so a round cannot last forever,
## not so it hands someone a win they did not earn — so a tie runs on into
## sudden death, and the next crystal to change hands, or the next team to be
## wiped out, ends it.


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Tuning")
## Ten minutes: short enough for mobile, which is what the whole match length
## is chosen for.
@export var duration: float = 600.0
@export_group("")

#endregion


#region ─────────────────────────────  the rule  ─────────────────────────────

func check(m: MatchManager) -> int:
	if m.elapsed < duration:
		return Teams.NO_TEAM

	var held: Dictionary[int, int] = {}
	for point: CapturePoint in m.map.capture_points:
		if point.owner_team == Teams.NO_TEAM:
			continue                    # nobody has ever taken it
		held[point.owner_team] = held.get(point.owner_team, 0) + 1

	var leader: int = Teams.NO_TEAM
	var most: int = 0
	var tied: bool = false
	for team_id: int in held:
		if held[team_id] > most:
			leader = team_id
			most = held[team_id]
			tied = false
		elif held[team_id] == most:
			tied = true
	if tied:
		return Teams.NO_TEAM            # sudden death, as above
	return leader                       # NO_TEAM when the map has no crystals held

#endregion
