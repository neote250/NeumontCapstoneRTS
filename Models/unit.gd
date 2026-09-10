extends Node3D
class_name Unit

## A unit is a container: a mesh plus its components. It has no movement or
## combat code of its own — the squad drives position, the components own the rest.

@export var health_component: HealthComponent
@export var weapon_component: WeaponComponent
@export var default_attack: Attack
