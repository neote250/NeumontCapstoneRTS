class_name SquadStats
extends Resource
## Tuning numbers for one squad type. Read-only at runtime — a resource is one
## object shared by every squad using it, so writing to one writes to all of
## them, and the change persists to the file on disk.
##
## The rule: the resource is the TYPE, the node is the INSTANCE. True of every
## skeleton mage squad, put it here. True of this squad right now, put it on
## Squad — see size_bonus there for the pattern.

@export_group("Movement")
@export var speed: float = 5.0
## How sharply the squad turns and accelerates. 0 = never arrives, 1 = instant.
@export_range(0.0, 1.0) var turn_smoothing: float = 0.1
@export var is_flying: bool = false

@export_group("Roster")
@export var unit_scene: PackedScene = preload("res://Models/unit.tscn")
## Base allowance. Upgrades add to it through Squad.size_bonus, and
## unit_spots.size() still caps it — see Squad.has_room().
@export var max_squad_size: int = 3
@export var spawning_size: int = 3
@export var formation_catchup_speed: float = 6.0

@export_group("Economy")
@export var unit_cost: int = 10
@export var squad_cost: int = 50
@export var squad_spawn_distance: float = 10.0

@export_group("Sensors")
## 0 on infantry, ~8 on buildings.
@export var vision_per_unit: float = 0.0
