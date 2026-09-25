class_name RosterComponent
extends Node
## Owns the squad's units: who is in it, where they stand, and how they leave.
## Anything that operates on the units lives here; anything that operates on
## the squad as a whole stays on Squad.


#region ─────────────────────────────  signals  ──────────────────────────────

## The roster changed size. Squad re-emits this as its own roster_changed(self),
## so the UI stays coupled to Squad rather than reaching into this component.
signal changed(size: int)
## The last unit died. Squad decides what that means — a component that frees
## its own parent is a component you cannot reuse.
signal emptied

#endregion


#region ────────────────────────────  constants  ─────────────────────────────

## How close a unit must be to its slot before it stops nudging toward it.
const ARRIVAL_THRESHOLD: float = 0.05

#endregion


#region ──────────────────────────  configuration  ───────────────────────────

@export_group("Wiring")
@export var stats: SquadStats

@export_group("Contents")
## Left empty in both squad scenes and discovered in _ready() — the units and
## markers are authored on the squad, not on this node.
@export var all_units: Array[Unit] = []
@export var unit_spots: Array[Marker3D] = []
@export_group("")

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

#region runtime modifiers — granted by upgrades, live here not on the resource
## Extra roster slots from upgrades. stats.max_squad_size is the base.
var size_bonus: int = 0
## Extra crystal per unit per second from upgrades. stats.capture_weight is
## the base. Nothing grants it yet; the field exists so the buff has a home
## the day a crystal or a building hands one out.
var capture_weight_bonus: float = 0.0
#endregion

var _squad: Squad
var _ground_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
## Which unit gets its ground raycast this frame. One per frame, round-robin.
var _stagger: int = 0

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	_squad = get_parent() as Squad

	# Load-bearing: neither squad scene sets these, and both the units and the
	# markers are authored on the squad, not on this node.
	if all_units.is_empty():
		all_units.assign(NodeUtil.children_of_type(_squad, Unit))
	if unit_spots.is_empty():
		unit_spots.assign(NodeUtil.children_of_type(_squad, Marker3D))

	for unit: Unit in all_units:
		_connect(unit)

	# The initial fill-out is deliberately NOT here. A child's _ready() runs
	# while the parent is still blocked from gaining children, so add_child()
	# is refused. Squad calls spawn_to_size() from its own _ready(), by which
	# point Godot has lifted the block.

## Fill the roster out to its starting size. Called by Squad._ready(), not from
## our own _ready() — see the note above. add_unit() refuses past max_size(),
## so a spawning_size above the cap quietly yields the cap.
func spawn_to_size() -> void:
	for i: int in maxi(0, stats.spawning_size - all_units.size()):
		add_unit()


#region queries

#endregion


#region ─────────────────────────────  queries  ──────────────────────────────

func size() -> int:
	return all_units.size()

func is_empty() -> bool:
	return all_units.is_empty()

## Base allowance plus anything upgrades have granted.
func max_size() -> int:
	return stats.max_squad_size + size_bonus

## How fast this squad takes a crystal: weight per unit, times units alive.
## Read by CapturePoint, which knows nothing about squads beyond this number.
func capture_rate() -> float:
	return (stats.capture_weight + capture_weight_bonus) * size()

## mini() keeps the authored spot count authoritative — an upgrade raises the
## player-facing permission, never the number of markers the scene has.
func has_room() -> bool:
	return all_units.size() < mini(max_size(), unit_spots.size())

func random_unit() -> Unit:
	return all_units[randi() % all_units.size()]

## The attack the squad's range checks are measured with. Unit 1 speaks for all.
func current_attack() -> Attack:
	if all_units.is_empty():
		return null
	return all_units[0].weapon_component.current_attack

#endregion


#region membership

#endregion


#region ────────────────────────────  membership  ────────────────────────────

## A mechanic, not a purchase. Build.complete(), _ready() and the debug hotkey
## all land here. Never touches shards.
## TODO tell the RTS controller to increase vision when the roster grows.
## TODO disable the UI's recruit button once the squad is at max size.
func add_unit() -> bool:
	if not has_room():
		return false
	var unit: Unit = stats.unit_scene.instantiate() as Unit
	_squad.add_child(unit)
	unit.global_position = unit_spots[all_units.size()].global_position
	unit.global_rotation = _squad.global_rotation
	all_units.append(unit)
	_connect(unit)
	changed.emit(all_units.size())
	return true

func remove_unit(unit: Unit) -> void:
	all_units.erase(unit)
	unit.queue_free()
	changed.emit(all_units.size())
	if all_units.is_empty():
		emptied.emit()

func grant_weapon(attack_scene: PackedScene) -> bool:
	if attack_scene == null or all_units.is_empty():
		return false
	for unit: Unit in all_units:
		var atk: Attack = attack_scene.instantiate() as Attack
		unit.weapon_component.add_child(atk)
		unit.weapon_component.attack_options.append(atk)
		if unit.weapon_component.current_attack == null:
			unit.weapon_component.current_attack = atk
	return true

func _connect(unit: Unit) -> void:
	unit.health_component.died.connect(remove_unit)
	unit.weapon_component.deal_damage.connect(_squad.on_damage_dealt)

#endregion


#region placement — called from Squad._physics_process, in order

#endregion


#region ──────────────────────────────  combat  ──────────────────────────────

## Every unit takes a shot with whatever it is holding.
## TODO call the connected firing animation from here.
func fire_all(delta: float) -> void:
	for unit: Unit in all_units:
		unit.weapon_component.damage_target(delta)

#endregion


#region ────────────────────────────  placement  ─────────────────────────────

## Step each unit toward its formation slot. Local space, x and z only:
## snap_to_ground() owns y, and mixing them fights over one axis.
func align_to_slots(delta: float) -> void:
	for i: int in mini(all_units.size(), unit_spots.size()):
		var unit: Unit = all_units[i]
		var slot: Vector3 = unit_spots[i].position   # local to the squad
		var offset: Vector3 = slot - unit.position   # local minus local = local
		offset.y = 0.0                               # ground pass owns y
		var distance: float = offset.length()

		if distance <= ARRIVAL_THRESHOLD:
			unit.position.x = slot.x                 # settle exactly, stop jittering
			unit.position.z = slot.z
			continue

		# Never step further than the remaining distance — no overshoot.
		var step: Vector3 = offset / distance * minf(stats.formation_catchup_speed * delta, distance)
		unit.position.x += step.x
		unit.position.z += step.z

## One unit per physics frame — a 5-unit squad fully refreshes 12x/second.
func snap_to_ground() -> void:
	if stats.is_flying or all_units.is_empty():
		return
	_stagger = (_stagger + 1) % all_units.size()
	Ground.snap(all_units[_stagger], _ground_query)

#endregion

#endregion
