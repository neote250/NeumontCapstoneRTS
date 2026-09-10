class_name Ground
## Terrain height queries. Layer 2 is the ground collision layer.

const MASK: int = 2
const CAST_UP: float = 5.0
const CAST_DOWN: float = 20.0

## Drop `node` onto the terrain beneath it. Takes the query object as an
## argument so callers reuse one instead of allocating every physics frame.
## Split across lines deliberately: if either lookup ever returns null, the
## error names which one instead of blaming the whole chain.
static func snap(node: Node3D, query: PhysicsRayQueryParameters3D) -> void:
	var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
	query.from = node.global_position + Vector3.UP * CAST_UP
	query.to = node.global_position + Vector3.DOWN * CAST_DOWN
	query.collision_mask = MASK
	var hit: Dictionary = space.intersect_ray(query)
	if hit:
		node.global_position.y = hit.position.y
