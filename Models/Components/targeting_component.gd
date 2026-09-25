class_name TargetingComponent
extends Node
## Who are we shooting at, and can we reach them. Stance stays on Squad —
## that is a player-facing order, not a query.


#region ─────────────────────────────  signals  ──────────────────────────────

signal target_changed(target: Squad)

#endregion


#region ──────────────────────────────  state  ───────────────────────────────

## The squad we are currently engaging, or null.
var target: Squad

var _squad: Squad
var _shape: SphereShape3D = SphereShape3D.new()
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

#endregion


#region ────────────────────────────  lifecycle  ─────────────────────────────

func _ready() -> void:
	_squad = get_parent() as Squad
	_query.shape = _shape
	# Search the layer we occupy, so every squad is findable to every other.
	# This works because all squads share one layer — the day buildings move to
	# their own, this needs an explicit SQUAD_LAYER constant instead.
	_query.collision_mask = _squad.collision_layer
	_query.exclude = [_squad.get_rid()]


#region the target

#endregion


#region ────────────────────────────  the target  ────────────────────────────

func set_target(new_target: Squad) -> void:
	if new_target == target:
		return
	target = new_target
	target_changed.emit(new_target)

func remove_target() -> void:
	set_target(null)

func has_target() -> bool:
	return is_instance_valid(target)

#endregion


#region range

#endregion


#region ──────────────────────────────  range  ───────────────────────────────

## Is the current target inside our weapon's reach?
func target_in_range() -> bool:
	var attack: Attack = _squad.roster.current_attack()
	if attack == null or not has_target():
		return false
	return is_within_xz_range(target.global_position, attack.attack_range)

## Ignoring y is correct and should stay. The reason is design, not
## performance: a squad on a hill 15 m above another should still be in weapon
## range, and using true 3D distance would let elevation silently eat the range
## budget, making combat unpredictable on slopes. Nearly every RTS does
## horizontal-only range for exactly this.
func is_within_xz_range(location: Vector3, radius: float) -> bool:
	var dx: float = location.x - _squad.global_position.x
	var dz: float = location.z - _squad.global_position.z
	return dx * dx + dz * dz < radius * radius   # no square root

## The actual horizontal distance, for a UI readout, a debug overlay, or the
## leash check ai_idle_state will need. Not used by the range test above.
func xz_distance_to(location: Vector3) -> float:
	var dx: float = location.x - _squad.global_position.x
	var dz: float = location.z - _squad.global_position.z
	return sqrt(dx * dx + dz * dz)

#endregion


#region ───────────────────────────  acquisition  ────────────────────────────

## Nearest hostile squad inside the current weapon's radius, or null.
func nearest_hostile() -> Squad:
	var attack: Attack = _squad.roster.current_attack()
	if attack == null:
		return null
	_shape.radius = attack.attack_range
	_query.transform = _squad.global_transform

	var closest: Squad = null
	var closest_distance: float = INF
	var space: PhysicsDirectSpaceState3D = _squad.get_world_3d().direct_space_state
	for result: Dictionary in space.intersect_shape(_query):
		var body: Squad = result["collider"] as Squad
		if body == null or not Teams.is_hostile(_squad.player_id, body.player_id):
			continue
		var d: float = _squad.global_position.distance_squared_to(body.global_position)
		if d < closest_distance:
			closest_distance = d
			closest = body
	return closest

#endregion

#endregion
