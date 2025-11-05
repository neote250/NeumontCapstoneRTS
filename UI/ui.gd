extends Control
class_name Player_UI

signal Change_State(new_state: GlobalEnums.STATES)


#pointer to current model (unit/building) being controlled
var current_controlled

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var selection_wheel: SelectionWheel = $CanvasLayer/Selection_Wheel
@onready var testing_data_label: Label = $CanvasLayer/TestingDataLabel

@export var owning_player: RTSController


@onready var squad_active: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/SquadActive
@onready var unit_1: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Unit1
@onready var unit_2: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Unit2
@onready var unit_3: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Unit3
@onready var unit_4: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Unit4
@onready var unit_5: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/Unit5
@onready var squad_info: Control = $CanvasLayer/SquadInfoPanel/SquadInfoBox/SquadInfo






func _ready() -> void:
	if !owning_player:
		owning_player = get_parent()
	


func change_testing_data_text(text) -> void:
	if typeof(text) == TYPE_STRING:
		testing_data_label.text = text
	if typeof(text) == TYPE_INT:
		testing_data_label.text = text
	if typeof(text) == TYPE_VECTOR2:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.y)
	if typeof(text) == TYPE_VECTOR3:
		testing_data_label.text = String.num(text.x) + " " + String.num(text.z)


	#for squad in owning_player.all_squads:
		#
func update_player_unit_details() -> void:
	var number_of_units_left: int = owning_player.current_squad.all_units.size()
	
	while number_of_units_left > 0:
		
		number_of_units_left -= 1



#move _process to here when have time for optimization
func _input(event: InputEvent) -> void:
	pass



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("input_wheel"):
		selection_wheel.show()
	elif Input.is_action_just_released("input_wheel"):
		var selection = selection_wheel.Close()
		#then change the state of the unit being controlled with the selection
		Change_State.emit(selection)
	
	
