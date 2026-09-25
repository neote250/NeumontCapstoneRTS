extends Node
class_name Controller
## Owns squads, and nothing else — no camera, no input, no purse. Every squad
## in the match belongs to exactly one of these.
##
## The rule for what lives here: anything an owner of squads needs whether or
## not anyone is pressing buttons. A player's RTSController is this plus hands;
## the map's NeutralController is this and nothing more.


#region ─────────────────────────────  signals  ──────────────────────────────

## A squad joined or left this roster. Only the squad is sent: a listener that
## needs its position or the count asks all_squads, so nothing here goes stale.
signal added_squad(new_squad: Squad)
signal removed_squad(removed_squad: Squad)

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Ownership")
## Which player this is. Teams.NEUTRAL (-1) on the NeutralController.
@export var player_id: int = 0
## Which side this player is on. Players on the same team never target each
## other. Every player needs one; only the NeutralController stays on NO_TEAM.
## TODO stage 3: set by the match from MatchConfig, not in the inspector.
@export var team_id: int = Teams.NO_TEAM

@export_group("Wiring")
## Where squads this controller spawns are placed in the world. Custody only:
## ownership is each squad's controller field, and squads are found through
## Squad.GROUP, so where a squad sits never decides whose it is. Set by the
## match for the players it builds; authored for the map's own controllers.
## Must sit above whatever spawns squads in the scene tree — add_squad() says
## why, and refuses when it does not.
@export var squads_root: Node
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## The one record of what this controller owns. Deliberately not exported:
## nothing authors it, so a broken class_name cannot drop it. Written only by
## adopt() and _on_squad_terminated().
var all_squads: Array[Squad] = []

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	_adopt_placed_squads()

#endregion


#region ───────────────────────────  squad roster  ───────────────────────────

## Mechanic. Instantiate a squad, place it in the world, and take ownership.
## The squad is ready by the time this returns — which is a claim about scene
## order, so it is checked rather than hoped for.
func add_squad(scene: PackedScene, where: Vector3) -> Squad:
	# Godot runs _ready() on a new child only if the parent has been readied
	# itself (Node::_set_tree — "if (!data.parent || data.parent->
	# data.ready_notified)"). Spawn into a node that has not had its turn and
	# the squad enters the tree but stays half-built until that node readies:
	# no camera mount, no units, no state machine. Tree order is the whole of
	# it, and nothing in the inspector hints at it, so name it here.
	if not squads_root.is_node_ready():
		push_error("%s: Squads Root '%s' has not been readied yet, so a squad spawned into it would come back half-built. Move '%s' above whatever spawns squads in the scene tree." % [name, squads_root.name, squads_root.name])
		return null
	var new_squad: Squad = scene.instantiate() as Squad
	if new_squad == null:
		return null
	new_squad.controller = self        # before add_child — Squad._ready() checks it
	squads_root.add_child(new_squad)
	new_squad.global_position = where
	adopt(new_squad)
	return new_squad

## The only way into all_squads. Buying, map placement and, later, gifting all
## come through here, so they cannot disagree about what owning a squad means.
func adopt(squad: Squad) -> void:
	squad.controller = self
	squad.squad_terminated.connect(_on_squad_terminated)
	all_squads.append(squad)
	added_squad.emit(squad)

## This controller's bookkeeping only: drop the squad and announce it. Knows
## nothing about other players or the match. RTSController adds selection.
func _on_squad_terminated(dead_squad: Squad) -> void:
	var i: int = all_squads.find(dead_squad)
	if i == -1:
		return
	all_squads.remove_at(i)
	removed_squad.emit(dead_squad)

## The non-death twin of _on_squad_terminated(): let go of a squad that is
## still alive, because it is being handed to someone else. Both paths end in
## removed_squad, so a listener never has to know which happened — which is
## what lets the UI treat "no squads left" the same either way.
func release(squad: Squad) -> void:
	var i: int = all_squads.find(squad)
	if i == -1:
		push_error("%s does not own '%s', so it cannot release it." % [name, squad.name])
		return
	squad.squad_terminated.disconnect(_on_squad_terminated)
	all_squads.remove_at(i)
	removed_squad.emit(squad)

## Hand a squad to another controller — the teammate rescue.
##
## Nothing is copied. SquadStats is shared by reference and every runtime
## modifier lives on the squad's own nodes, so upgrades travel by staying
## exactly where they are; adopt() sets controller, and player_id is derived
## from it, so no third record has to be told. A handover is a change of
## manager, not a trade.
func give(squad: Squad, to: Controller) -> void:
	if to == null or to == self:
		return
	release(squad)
	to.adopt(squad)

## Squads the map places itself — wild camps, and whatever else a level author
## stands on the ground — say who owns them through their controller field.
## Collect ours. Searched by group, not by tree, so a squad is found wherever
## it sits. A player's squads do not come this way: the match spawns them
## through add_squad(), so for a player this finds nothing.
func _adopt_placed_squads() -> void:
	for node: Node in get_tree().get_nodes_in_group(Squad.GROUP):
		var squad: Squad = node as Squad
		if squad.controller == self:
			adopt(squad)

#endregion
