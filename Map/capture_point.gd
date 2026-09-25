extends Area3D
class_name CapturePoint
## A crystal: who holds it, and how close someone is to taking it. Knows
## nothing about winning — the match asks it who its owner is and counts.
##
## An Area3D rather than a shape query, which is what TargetingComponent uses:
## that asks from wherever a squad happens to be standing, while a crystal is
## fixed, so the physics server can keep the overlap list and this only reads
## it. Needs a CollisionShape3D child, and a Collision Mask on the layer squads
## occupy — layer 3 today, the same one every squad sets.
##
## The shape is the region, and that is the whole of "region locked". A crystal
## in a cave gets a volume sized to the cave, so a squad on the hill above it is
## outside and simply does not count; one in a river gets a shape that follows
## the riverbed. Nothing here knows what a cave or a river is. Who can physically
## get there is movement's question, not this node's — a crystal only ever asks
## who is standing in it, and _may_capture() asks whether they are allowed to.


#region ─────────────────────────────  signals  ──────────────────────────────

## The crystal changed hands. Carries itself, so one listener can serve every
## crystal on the map.
signal owner_changed(point: CapturePoint, new_team: int)

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Tuning")
## Rate-seconds needed to fill the bar. A three-unit squad of capture weight
## 1.0 supplies 3 a second, so at 30 it takes ten seconds to take a neutral
## crystal — and twenty to take a held one, since the holder's claim has to be
## drained to nothing first.
## Ranged rather than guarded: _advance() divides by it, and the inspector
## refusing 0 is cheaper than a check that runs every physics frame.
@export_range(0.5, 300.0, 0.5, "or_greater") var capture_cost: float = 30.0

@export_group("Access")
## Flying squads are present but not counted. On for a crystal that has to be
## stood in rather than passed over — under water, down a cave, inside a
## building — since a flier skips snap_to_ground() and will otherwise hover
## inside the shape and take it without ever arriving.
## Off leaves an open-air crystal contestable by anything that can reach it.
## A squad ruled out here does not contest either — if you cannot take it you
## cannot deny it, or one flier would lock a crystal it can never own.
@export var ground_only: bool = false
@export_group("")

@export_group("Debug")
## TEMPORARY. Nothing draws a capture bar yet, so this is how 4a is testable on
## its own: point it at a Label3D above the crystal and it prints the state.
## Delete once the real indicator exists.
@export var readout: Label3D
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## The team that scores this crystal. Changes only when someone else fills the
## bar — walking away never gives it back, which is what makes a partial push
## by an attacker worth nothing until it is finished.
var owner_team: int = Teams.NO_TEAM
## Whose bar `progress` currently is. Not the same question as who owns it: an
## attacker's claim rises while the defender is still the owner.
var claiming_team: int = Teams.NO_TEAM
## 0 to 1, toward claiming_team.
var progress: float = 0.0

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _physics_process(delta: float) -> void:
	_advance(delta)
	_show()

#endregion


#region ────────────────────────────  capturing  ─────────────────────────────

## One step of the bar. Contesting freezes it outright rather than fighting
## over the direction: any second side present and nothing moves, whatever the
## weights are, so a crystal has to be cleared before it can be taken.
func _advance(delta: float) -> void:
	var rates: Dictionary[int, float] = _rate_by_side()
	if rates.size() != 1:
		return                          # empty, or contested — the bar holds
	var side: int = rates.keys()[0]
	if side == Teams.NO_TEAM:
		return                          # a wild camp holds a crystal; it never takes one

	var step: float = rates[side] * delta / capture_cost
	if claiming_team == Teams.NO_TEAM:
		claiming_team = side            # nobody's bar yet, so it is theirs to fill

	if side == claiming_team:
		progress = minf(progress + step, 1.0)
		if progress >= 1.0 and owner_team != side:
			owner_team = side
			owner_changed.emit(self, side)
	else:
		progress = maxf(progress - step, 0.0)
		if progress == 0.0:
			claiming_team = side        # their claim is erased; ours starts next frame

## How fast each side present is capturing, keyed by team id. Grouped by
## Controller.team_id rather than player_id, so two teammates standing on one
## crystal add up instead of deadlocking it. Wild squads land under NO_TEAM,
## which is correct: they are one side, they fight everyone, and _advance()
## refuses to let them own anything.
func _rate_by_side() -> Dictionary[int, float]:
	var rates: Dictionary[int, float] = {}
	for body: Node3D in get_overlapping_bodies():
		var squad: Squad = body as Squad
		if squad == null or squad.controller == null:
			continue                    # Squad._ready() already named an unowned squad
		if not _may_capture(squad):
			continue
		var side: int = squad.controller.team_id
		rates[side] = rates.get(side, 0.0) + squad.roster.capture_rate()
	return rates

## May this squad take this crystal at all? One function on purpose, even at one
## rule: the same move that let Teams.is_hostile() change at stage 2 without
## touching a caller. Every later access rule lands here.
## TODO when squads gain movement kinds beyond is_flying — swimming, burrowing —
## this becomes "does the squad's kind appear in the crystal's allowed list?",
## and ground_only becomes one authored list rather than a bool. Not built now:
## one bool that is honest beats a tag system invented before the tags exist.
func _may_capture(squad: Squad) -> bool:
	if ground_only and squad.stats.is_flying:
		return false
	return true

#endregion


#region ──────────────────────────  debug readout  ───────────────────────────

## TEMPORARY, with the export above.
func _show() -> void:
	if readout == null:
		return
	readout.text = "owner %d\nclaim %d\n%d%%" % [owner_team, claiming_team, roundi(progress * 100.0)]

#endregion
