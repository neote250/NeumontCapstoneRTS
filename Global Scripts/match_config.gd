extends Resource
class_name MatchConfig
## What the lobby decided: who is playing, on which sides, and under what
## rules. Pure data with no nodes, which is what makes it the thing to send
## over a wire at match start, and the thing a story map ships as a preset.
##
## It says nothing about which seat is yours: the same config runs on every
## machine, and MatchManager.local_player_id is what differs between them.


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Seats")
@export var players: Array[PlayerSetup] = []

@export_group("Rules")
## The squads every player starts with, spawned as a group on the base spot
## they were dealt.
## TODO per-seat starting groups, once a mode wants asymmetric starts.
@export var starting_group: Array[PackedScene] = []
## Read into Teams at startup.
## TODO leave this false until is_hostile() is split into "pick as a target?"
## and "does this hit count?" — see the plan, stage 2. Switching it on today
## would have teammates hunt each other.
@export var friendly_fire: bool = false
## What ends the round. A list, not one: a standard round runs elimination and
## a clock at once and either can finish it. Checked in order, and the first
## side named wins, so put the decisive rule first if two could ever answer on
## the same frame.
@export var win_conditions: Array[WinCondition] = []
@export_group("")

# TODO later: which map to load, once something other than the map itself
# starts the match.

#endregion
