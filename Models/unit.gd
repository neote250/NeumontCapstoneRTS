extends Node3D
class_name Unit


#info given to units
var target_position: Vector3
var can_move: bool = true
var has_target_position: bool = true   ###
var is_moving: bool = false
var is_attacking: bool = false


#unit stats
@export var speed: float = 5.0
@export var health_component : HealthComponent
@export var weapon_component : WeaponComponent
@export var default_attack: Attack

func _ready() -> void:
	if !health_component:
		for child: Node in get_children():
			if child is HealthComponent:
				health_component = child
	if !weapon_component:
		for child: Node in get_children():
			if child is WeaponComponent:
				weapon_component = child
	if !default_attack:
		for child: Node in get_children(true):
			if child is Attack:
				default_attack = child
	
