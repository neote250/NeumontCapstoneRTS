extends Node3D
class_name Map
## What this place offers, and nothing about who is playing on it. A map that
## knows no players can serve a 1v1 and a 3v3 without being edited, and the
## match reads it to build the world.
##
## This script goes on the root of a map scene: the map is the map.


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Wiring")
## The heightmap this place is built on. The local player hands it a camera,
## which is what Terrain3D uses to decide level of detail.
@export var terrain: Terrain3D
## Where squads stand in the world. The match hands it to every controller it
## builds, so custody belongs to the place rather than to any player.
## Place it above the MatchManager in this scene: a squad spawned into a node
## that has not been readied yet stays half-built. Controller.add_squad()
## carries the explanation, and refuses rather than hand back a broken squad.
@export var squads_root: Node

@export_group("Sites")
## The places a base can stand. At match start they are the deal pool: each
## player's starting group lands on one, and a dealt spot leaves the pool, so
## a map needs at least as many spots as the match has players. A carried base
## is later placed on one of the rest.
@export var base_spots: Array[Marker3D] = []
## The crystals. Held for score, and later for the team buff they grant. The
## map publishes them; what winning means is the match's business.
@export var capture_points: Array[CapturePoint] = []
@export_group("")

# TODO later: build_spots, once BuildSpot is designed (the plan, section 06).

#endregion


#region ──────────────────────────────  ground  ──────────────────────────────

## How high the ground is at `where`, or NAN where this map has no terrain.
##
## Asked of the heightmap rather than cast for: while the match builds its
## world nothing has stepped the physics space yet, so a ray would find
## nothing. It also means a base spot can be authored at any height — the
## marker says where, the terrain says how high.
func height_at(where: Vector3) -> float:
	return terrain.data.get_height(where)

#endregion
