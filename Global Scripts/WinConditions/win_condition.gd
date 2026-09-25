extends Resource
class_name WinCondition
## Does the round end, and who won? A Resource, like SquadStats: the rule is
## data a config can hold and a lobby can send, not a branch inside the match.
## A mode is a list of these.
##
## There is no Scripted subclass, though an earlier draft of the plan listed
## one. A map-authored objective is just another subclass, written next to the
## map that needs it — the base class already is the extension point, and an
## empty class named Scripted would add a name without adding a capability.


#region ─────────────────────────────  the rule  ─────────────────────────────

## The winning team, or Teams.NO_TEAM to let the round continue. Overridden by
## every subclass; the base answers "not yet" forever, which is the honest
## thing for a condition nobody has written a rule into.
##
## Takes the whole match rather than a digest of it: a later condition will
## want something today's two do not, and widening a digest means touching
## every subclass. MatchManager naming WinCondition while WinCondition names
## MatchManager is fine — Squad and RosterComponent already do it.
func check(_m: MatchManager) -> int:
	return Teams.NO_TEAM

#endregion
