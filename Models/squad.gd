extends Node3D
class_name Squad


#signals   !!!!!!! Need to rework these signals
signal selected
signal deselected
	#signal for when entire squad dies
signal squad_terminated(terminated_squad)


#targetting
var is_selected: bool = false
var target_position: Vector3
var has_target: bool = false
var squad_index: int


#variable unit info, obviously currently pointless
var unit_type = preload("res://Models/unit.tscn")
var max_squad_size: int = 5

#unit array stuff
var all_units: Array[Unit] = []
var current_unit_index: int = 0
var current_unit: Unit
var last_unit_index: int = -1

#camera
@onready var camera_mount: Node3D = $CameraMount

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var initial_units = get_tree().get_nodes_in_group("units_in_group")
	for unit in initial_units:
		if unit is Unit:
			all_units.append(unit)
	
	#if I want to change a unit's gear
	#current_unit = all_units[0]
	
	for unit in all_units:
		unit.health_component.died.connect(remove_unit)


#use these two signals to inform the UI of the squads details
func select():
	is_selected = true
	selected.emit(self)
#
func deselect():
	is_selected = false
	deselected.emit(self)






#movement of the squad
func move_to(target_position: Vector3):
	for unit in all_units:
		unit.target_position = target_position + unit.position
		has_target = true
		unit.has_target_position = true


func stop_movement():
	has_target = false
	target_position = self.position




#add another unit to the squad
func spawn_unit():
	var new_unit: Unit = unit_type
	self.add_child(new_unit)
	new_unit.add_to_group("units_in_group")
	new_unit.health_component.died.connect(remove_unit)

#remove a unit from the squad
func remove_unit(removed_unit: Unit):
	#check if no more units in squad
	if all_units.is_empty():
		squad_terminated.emit(self)
		self.queue_free()
	
	



func _process(delta: float) -> void:
	pass
