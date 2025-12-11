extends Control
class_name Player_UI

signal Change_State(new_state: GlobalEnums.STATES)
signal Change_Build_Option(changed_build:BuildProgress)

#pointer to current model (unit/building) being controlled
var current_controlled:Squad

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var selection_wheel: SelectionWheel = $CanvasLayer/Selection_Wheel
@onready var testing_data_label: Label = $CanvasLayer/TestingDataLabel

@export var owning_player: RTSController

@onready var resources: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Resources
@onready var memory_shards: Label = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Resources/MemoryShards

@onready var squad_info: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/SquadInfo


@export var display_builds_progress:Array[BuildProgress]
#@export var build_options: Array[Build]

var build_dict:Dictionary[Build, BuildProgress]

##Ensure controller is set
func _ready() -> void:
	if !owning_player:
		owning_player = get_parent()
	
	display_builds_progress[0].button.toggled.connect(send_toggle_1)
	display_builds_progress[1].button.toggled.connect(send_toggle_2)
	display_builds_progress[2].button.toggled.connect(send_toggle_3)
	display_builds_progress[3].button.toggled.connect(send_toggle_4)
	display_builds_progress[4].button.toggled.connect(send_toggle_5)

##Supposed to be ui informs the controller which button is pressed, but currently not sure if working.
func tell_controller_build_selected(build:BuildProgress):
	#Handle visuals here for ui
	
	Change_Build_Option.emit(build)

##Just testing data visuals
func change_testing_data_text(text) -> void:
	if typeof(text) == TYPE_STRING:
		testing_data_label.text = text
	if typeof(text) == TYPE_INT:
		testing_data_label.text = str(text)
	if typeof(text) == TYPE_VECTOR2:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.y)
	if typeof(text) == TYPE_VECTOR3:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.z)

##Reset the upgrade buttons, currently only hides all options and clears build array
func reset_buttons()->void:
	for option in display_builds_progress:
		option.visible = false
		
	build_dict.clear()

###Game manager calls this function to update visible unit details
func update_player_unit_details(_current_squad:Squad) -> void:
	#var number_of_units_left: int = owning_player.current_squad.all_units.size()
	
	#while number_of_units_left > 0:
		#
		#number_of_units_left -= 1
	
	#for index:int in range(number_of_units_left):
		#health_bars[index].visible = true
		#health_bars[index].init_health(owning_player.current_squad.all_units[index].health_component.Max_Health)
	
	
	
	
	#health_bars[0].visible = true
	#health_bars[1].visible = true
	#health_bars[2].visible = true
	#
	#
	#health_bars[0].init_health(owning_player.current_squad.all_units[0].health_component.Max_Health)
	#health_bars[1].init_health(owning_player.current_squad.all_units[1].health_component.Max_Health)
	#health_bars[2].init_health(owning_player.current_squad.all_units[2].health_component.Max_Health)
	
	##First hide all buttons
	reset_buttons()
	
	##Then show a button for each current squad build options and set the current progress
	var index:int = 0
	if !_current_squad.upgrades.is_empty():
		#for each build in the squad, match it to the build_progress bars in the ui
		for upgrade:Build in _current_squad.upgrades:
			##Visuals
			display_builds_progress[index].visible = true
			display_builds_progress[index].health_bar.health = upgrade.current_progress
			display_builds_progress[index].button.text = upgrade.to_string()
			
			##Need to have button toggle the squad's upgrade??
			
			
			##Array Stuff
			build_dict[upgrade] = display_builds_progress[index]
			index+=1
		
	

func send_toggle_1(toggled_on:bool)->void:
	#for build:Build in build_dict.values():
	if !build_dict.is_empty():
		build_dict.keys()[0].is_building = toggled_on
	#var this_squad:Squad = build_dict.keys()[0].get_parent() as Squad
	
	return

func send_toggle_2(toggled_on:bool)->void:
	if !build_dict.size()>1:
		build_dict.keys()[1].is_building = toggled_on
	return
func send_toggle_3(toggled_on:bool)->void:
	if !build_dict.size()>2:
		build_dict.keys()[2].is_building = toggled_on
	return
func send_toggle_4(toggled_on:bool)->void:
	if !build_dict.size()>3:
		build_dict.keys()[3].is_building = toggled_on
	return
func send_toggle_5(toggled_on:bool)->void:
	if !build_dict.size()>4:
		build_dict.keys()[4].is_building = toggled_on
	return


#move _process to here when have time for optimization
func _input(event: InputEvent) -> void:
	pass

##VISUALS
func _physics_process(delta: float) -> void:
	#for unit: Unit in owning_player.current_squad:
		#pass
	memory_shards.text = str(snapped(owning_player.memory_shards, 0.1))
	
	#if build_options.is_empty():
		#return
	#var index:int = 0
	for _build:Build in build_dict.keys():
		build_dict[_build].health_bar.health = _build.current_progress



func _process(delta: float) -> void:
	if Input.is_action_just_pressed("input_wheel"):
		selection_wheel.show()
	elif Input.is_action_just_released("input_wheel"):
		var selection:GlobalEnums.STATES = selection_wheel.Close()
		#then change the state of the unit being controlled with the selection
		Change_State.emit(selection)
	
	
