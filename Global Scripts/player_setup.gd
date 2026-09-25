extends Resource
class_name PlayerSetup
## One seat in the match: who a player is and which side they are on. Pure
## data — the match turns each of these into a controller.


#region ────────────────────────────  constants  ─────────────────────────────

## What plays this seat. A human seat is played from a machine; an AI seat will
## get a brain node once one exists.
enum KIND { HUMAN, AI }

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export var player_id: int = 0
@export var team_id: int = 0
## Unread for now — every seat that is not this machine's local player is built
## as a plain Controller either way, and simply does nothing.
## TODO give an AI seat its brain node when there is one to give.
@export var kind: KIND = KIND.HUMAN

#endregion
