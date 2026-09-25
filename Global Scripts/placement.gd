extends RefCounted
class_name Placement
## Where several things stand around one point. Static and stateless: the
## answer depends only on the arguments, so it can be read, reasoned about and
## reused without owning anything.


#region ────────────────────────────  constants  ─────────────────────────────

## Metres between neighbours in a ring. A squad's body is about 7 by 4.5, so
## this leaves a gap rather than having them touch shoulders.
const DEFAULT_SPACING: float = 10.0

#endregion


#region ──────────────────────────────  rings  ───────────────────────────────

## Where thing number `index` of `count` stands in a ring around `centre`.
##
## The radius follows the count rather than being fixed: the circle is made
## long enough to give every member `spacing` of arc, so two squads stand
## across from each other and ten stand in a wide circle instead of inside one
## another. y is the centre's — the ground pass owns height.
static func ring(centre: Vector3, index: int, count: int, spacing: float = DEFAULT_SPACING) -> Vector3:
	if count <= 1:
		return centre
	var radius: float = maxf(spacing, spacing * count / TAU)
	var angle: float = TAU * index / count
	return centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

#endregion
