extends Node

@export var teams:Array[RTSController]
@export var wild_squads:Array[Squad]

#handle player win condition
#if team loses all controllable models (buildings & units) then lose the game

###Damage target Squad
func damage(gm_attack:Attack, gm_target_squad:Squad) -> void:
	match gm_target_squad.player_id:
		-1:
			if gm_target_squad: gm_target_squad.take_damage(gm_attack)
		0:
			#player controller stuff
			if gm_target_squad: gm_target_squad.take_damage(gm_attack)
		_:
			pass#default case


###
func added_squad_connect()->void:
	pass

###Handle clean up of destroyed squad in proper order
func destroy_squad_cleanup(destroyed_squad:Squad) -> void:
	#first what team was the destroyed squad in
	match destroyed_squad.player_id:
		-1:	#Wild squads
			$"../Player".ui.change_testing_data_text("destroyed wild squad")
			#for squad: Squad in teams[0].all_squads:
				#if squad.target_squad == destroyed_squad:
					#squad.target_squad = null
					#squad.has_target = false
		0:	#player 1 and so on
			$"../Player".ui.change_testing_data_text("destroyed player 1 squad")
		_:
			$"../Player".ui.change_testing_data_text("Something went wrong")
	
	#destroyed_squad.remove_squad()

func squad_selected(_selected_squad:Squad) -> void:
	teams[0].current_squad.set_target(_selected_squad)
	#print("squad selected: " + str(_selected_squad.squad_index))

func _ready() -> void:
	#connect to signal from squads
	for squad: Squad in teams[0].all_squads:
		squad.squad_terminated.connect(destroy_squad_cleanup)
		squad.GM_Deal_Damage.connect(damage)
	
	for squad: Squad in wild_squads:
		squad.squad_terminated.connect(destroy_squad_cleanup)
		squad.GM_Deal_Damage.connect(damage)
		squad.selected.connect(squad_selected)
