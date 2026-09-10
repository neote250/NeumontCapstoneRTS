extends Node

@export var teams:Array[RTSController]
@export var wild_squads:Array[Squad]

## Which controller receives local input. One client, one local player —
## in networked play this is the team this client owns.
@export var local_team_index: int = 0

#handle player win condition
#if team loses all controllable models (buildings & units) then lose the game

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


func register_squad(squad: Squad) -> void:
	if squad.squad_terminated.is_connected(destroy_squad_cleanup):
		return                                  # idempotent — safe to call twice
	squad.squad_terminated.connect(destroy_squad_cleanup)
	squad.damage_dealt.connect(damage)
	squad.selected.connect(squad_selected)



##the match's consequences: [br]	win/loss check, kill feed, score, death VFX. 
##[br]Can't know which squad a given player has selected.
func destroy_squad_cleanup(destroyed_squad:Squad) -> void:
	wild_squads.erase(destroyed_squad) # no-op if it wasn't a neutral
	# TODO: kill feed, score, win/loss check
	# if player loses all squads and no teammates, player loses the game
	# in multiplayer if the player loses all squads the teammates can give that player a squad so that player can rebuild/etc.
	# So the player with no squads should probably have a spectate mode
	# Spectate mode is also just nice to have as a feature

func squad_selected(clicked_squad:Squad) -> void:
	if not is_instance_valid(clicked_squad):
		return
	var me: RTSController = teams[local_team_index]
	if not is_instance_valid(me.current_squad):
		return
	if Teams.is_hostile(me.player_id, clicked_squad.player_id):
		me.current_squad.targeting.set_target(clicked_squad)          # enemy → attack it
	elif clicked_squad in me.all_squads:
		me.set_active_squad(me.all_squads.find(clicked_squad))  # own squad → select it

func _ready() -> void:
	#connect to signal from squads
	for team: RTSController in teams:
		for squad: Squad in team.all_squads:
			register_squad(squad)
		team.added_squad.connect(register_squad)   # catch runtime squads
	
	for squad: Squad in wild_squads:
		register_squad(squad)
