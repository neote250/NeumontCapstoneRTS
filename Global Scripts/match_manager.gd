extends Node
class_name MatchManager
## The match. Owns what a hit *means* — score, kill feed, win and loss — as
## opposed to how it was fired. Squads report to it; it never commands them.
##
## The seam: a controller does one player's bookkeeping, this owns the
## consequences that span players.
##
## Named MatchManager rather than Match because `match` is a GDScript keyword,
## and a class one capital away from it makes code and searches ambiguous.


#region ─────────────────────────────  signals  ──────────────────────────────

## The round is over, and this team won. Emitted once: `winner` latches, so a
## later condition cannot end an already-ended match.
signal match_ended(winning_team: int)

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Match")
## What the lobby decided: the seats, their sides, and the rules. A preset
## .tres until there is a lobby to build one.
@export var config: MatchConfig
## Which seat this machine plays. The config is identical on every machine in
## networked play; this is the line that differs between them.
@export var local_player_id: int = 0
## Built for the local seat only — a controller with a camera, a UI and a
## minimap. Every other seat is a plain Controller, which needs no scene.
@export var player_scene: PackedScene

@export_group("Wiring")
## The place being played on: the spots to deal, and the ground to stand on.
@export var map: Map
## The map's own neutral owner. Wild camps are level design, so the match does
## not build them — it registers them alongside the players it did build.
@export var neutral: NeutralController
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## Every owner of squads in this match: the players built from the config, and
## the map's neutral. Built once, at startup.
var controllers: Array[Controller] = []
## The sides, built from the same config.
var teams: Array[Team] = []
## The seat this machine plays. Clicks and the UI go through it.
var local_player: RTSController = null

## Seconds since the world was built. Read by any condition that cares about
## time; accumulated here so every one of them agrees on the number.
var elapsed: float = 0.0
## Who won, or NO_TEAM while the round is live. Latches: the first condition to
## answer is the answer.
var winner: int = Teams.NO_TEAM

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	_build_world()           # the players, and the squads they start with
	_build_teams()           # before anything can ask who is hostile to whom

	# Squads that already exist — the starting groups, and the map's own
	# neutrals — are registered here; every later one arrives through the signal.
	for controller: Controller in controllers:
		for squad: Squad in controller.all_squads:
			register_squad(squad)
		controller.added_squad.connect(register_squad)   # catch runtime squads

	# Elimination can only change when a squad dies, so it is checked there.
	# This covers conditions that turn on time instead. One second rather than
	# every frame: a full team scan sixty times a second answers a question
	# that changes maybe twice a match. Built here rather than authored so a
	# map cannot forget it.
	var clock: Timer = Timer.new()
	clock.wait_time = 1.0
	clock.timeout.connect(_check_win)
	add_child(clock)
	clock.start()

func _process(delta: float) -> void:
	elapsed += delta

#endregion


#region ────────────────────────  building the world  ────────────────────────

## Build the match this map is hosting: one controller per seat in the config,
## each dealt a base spot with its starting group standing on it. The map's own
## squads are left alone — it keeps its neutrals.
## The order matters: everything a controller needs is set before it is added
## to the tree, because add_child() is when its _ready() runs.
func _build_world() -> void:
	if config == null:
		push_error("%s has no Match Config. There is no match to build." % name)
		return
	if map == null:
		push_error("%s has no Map. There is nowhere to build the match." % name)
		return
	var spots: Array[Marker3D] = map.base_spots.duplicate()
	if spots.size() < config.players.size():
		push_error("%s offers %d base spots for %d players." % [map.name, spots.size(), config.players.size()])
		return
	spots.shuffle()                       # dealt without replacement, below

	Teams.friendly_fire = config.friendly_fire
	for seat: PlayerSetup in config.players:
		var controller: Controller = _build_controller(seat)
		if controller == null:
			return                        # already named; a half-built match helps nobody
		controllers.append(controller)
		var spot: Marker3D = spots.pop_back()
		_spawn_starting_group(controller, spot)

	if neutral != null:
		controllers.append(neutral)       # in the map already, holding its own squads

	if local_player == null:
		push_error("No seat has Player Id %d, so this machine has nobody to play." % local_player_id)
		return
	# Guarded rather than assumed: _spawn_starting_group() gives up on a spot
	# it cannot stand on, and "index 0 out of bounds" would bury the error that
	# actually matters.
	if local_player.all_squads.is_empty():
		push_error("%s starts with no squads — see the error above." % local_player.name)
		return
	# The only seat with a screen to show a result on. Connected here rather
	# than called from _check_win(), so match_ended stays the one announcement
	# and a score screen or a replay can listen to it on the same terms.
	match_ended.connect(local_player.end_match)
	local_player.set_active_squad(0)

## One seat becomes one controller: the local seat gets the scene with the
## hands on it, every other seat a bare Controller, which is all an absent or
## remote player needs.
func _build_controller(seat: PlayerSetup) -> Controller:
	var controller: Controller
	if seat.player_id == local_player_id:
		local_player = player_scene.instantiate() as RTSController
		if local_player == null:
			push_error("Player Scene is not a scene whose root is an RTSController.")
			return null
		local_player.map = map            # before add_child: _ready() reads it
		controller = local_player
	else:
		controller = Controller.new()
	controller.name = "Player%d" % seat.player_id
	controller.player_id = seat.player_id
	controller.team_id = seat.team_id
	controller.squads_root = map.squads_root
	add_child(controller)
	return controller

## The starting group lands in a ring on its spot rather than on the point
## itself, or the squads would spawn inside one another. Each is placed at the
## ground's height where it actually stands, since a ring crosses a slope.
func _spawn_starting_group(controller: Controller, spot: Marker3D) -> void:
	for i: int in config.starting_group.size():
		var at: Vector3 = Placement.ring(spot.global_position, i, config.starting_group.size())
		at.y = map.height_at(at)
		if is_nan(at.y):
			push_error("%s is off the terrain — no ground at %v." % [spot.name, at])
			return
		controller.add_squad(config.starting_group[i], at)

#endregion


#region ──────────────────────────────  teams  ───────────────────────────────

## Group every player into its Team, then give Teams the lookup that hostility
## checks read. Names each wiring mistake rather than guessing past it.
func _build_teams() -> void:
	var by_id: Dictionary[int, Team] = {}
	var team_of: Dictionary[int, int] = {}              # player_id → team id
	var seen: Dictionary[int, Controller] = {}
	for controller: Controller in controllers:
		if controller.player_id == Teams.NEUTRAL:
			continue                        # neutrals are on no team
		if seen.has(controller.player_id):
			push_error("%s and %s share Player Id %d. Every player needs its own." % [seen[controller.player_id].name, controller.name, controller.player_id])
		seen[controller.player_id] = controller
		if controller.team_id == Teams.NO_TEAM:
			push_error("%s has no Team Id. Every player must be on a team." % controller.name)
			continue
		team_of[controller.player_id] = controller.team_id
		if not by_id.has(controller.team_id):
			by_id[controller.team_id] = Team.new(controller.team_id)
		by_id[controller.team_id].members.append(controller)
	teams.assign(by_id.values())
	Teams.set_roster(team_of)

#endregion


#region ───────────────────────────  registration  ───────────────────────────

func register_squad(squad: Squad) -> void:
	if squad.squad_terminated.is_connected(destroy_squad_cleanup):
		return                                  # idempotent — safe to call twice
	squad.squad_terminated.connect(destroy_squad_cleanup)
	squad.damage_dealt.connect(damage)
	squad.selected.connect(squad_selected)

#endregion


#region ──────────────────────────────  combat  ──────────────────────────────

##where "a hit landed" is observable, which is where score, kill feed, damage numbers, achievements and replays all hook in later. Keep it as a combat event bus, not as a damage calculator.[br]
##Is the target still alive, and is this allowed? Then: log it, score it, spawn a damage number
func damage(attacker: Squad, attack:Attack, target:Squad) -> void:
	if not is_instance_valid(target):
		return
	if not Teams.is_hostile(attacker.player_id, target.player_id):
		return
	target.take_damage(attack)

	# Possible future routing: branch on target.player_id so a hit on a
	# neutral, an ally and an enemy can score differently — a neutral kill
	# paying a bounty, friendly fire costing something, an enemy hit scoring
	# normally. Today every hostile hit takes the same path.

#endregion


#region ────────────────────────────  selection  ─────────────────────────────

func squad_selected(clicked_squad:Squad) -> void:
	if not is_instance_valid(clicked_squad):
		return
	var me: RTSController = local_player
	if not is_instance_valid(me.current_squad):
		return
	if Teams.is_hostile(me.player_id, clicked_squad.player_id):
		me.current_squad.targeting.set_target(clicked_squad)          # enemy → attack it
	elif clicked_squad in me.all_squads:
		me.set_active_squad(me.all_squads.find(clicked_squad))  # own squad → select it

#endregion


#region ───────────────────────────  consequences  ───────────────────────────

##the match's consequences: [br]	win/loss check, kill feed, score, death VFX. 
##[br]Can't know which squad a given player has selected.
func destroy_squad_cleanup(_destroyed_squad: Squad) -> void:
	# A death is the only thing that can eliminate a side, so both steps happen
	# here rather than on a poll.
	_update_elimination()
	_check_win()
	# TODO: kill feed, score, death VFX.

#endregion


#region ────────────────────────  winning and losing  ────────────────────────

## A side is eliminated when nobody on it owns anything — buildings included,
## since a building is a squad. Terminal by design: the `continue` means a team
## that is out stays out, and it is true anyway, because a side with nothing
## has no teammate left to be handed a squad by.
##
## A *player* with no squads is not eliminated, and nothing here says they are.
## That is spectate mode, and the UI asks all_squads directly.
func _update_elimination() -> void:
	for team: Team in teams:
		if team.eliminated:
			continue
		team.eliminated = not team.holds_squads()

## Ask each condition in turn and take the first answer. Latched on `winner`,
## so the clock firing a moment after an elimination cannot overwrite it.
func _check_win() -> void:
	if winner != Teams.NO_TEAM or config == null:
		return
	for condition: WinCondition in config.win_conditions:
		var result: int = condition.check(self)
		if result == Teams.NO_TEAM:
			continue
		winner = result
		match_ended.emit(winner)
		return

#endregion
