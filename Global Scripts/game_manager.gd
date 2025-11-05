extends Node

@export var teams:Array[RTSController]
@export var wild_squads:Array[Squad]


#handle player win condition
#if team loses all controllable models (buildings & units) then lose the game

###Handle clean up of destroyed squad in proper order
func destroy_squad_cleanup(destroyed_squad:Squad) -> void:
	#first what team was the destroyed squad in
	match destroyed_squad.player_id:
		-1:	#Wild squads
			$"../Player".ui.change_testing_data_text("destroyed wild squad")
		0:	#player 1 and so on
			for squad in teams[0].all_squads:
				if squad.target_squad == destroyed_squad:
					squad.target_squad = null
					squad.has_target = false
		_:
			$"../Player".ui.change_testing_data_text("Something went wrong")

	destroyed_squad.remove_squad()


#keep track of team's resources in player controller?
#player controller should manage 


func _ready() -> void:
	#connect to signal from squads
	for squad in teams[0].all_squads:
		squad.squad_terminated.connect(destroy_squad_cleanup)
	
	for squad in wild_squads:
		squad.squad_terminated.connect(destroy_squad_cleanup)
