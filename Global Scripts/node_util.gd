## Small shared helpers for finding things in the scene tree.
class_name NodeUtil

## Every direct child of `parent` that is an instance of `type`, in scene
## order. Call it with a class name: NodeUtil.children_of_type(self, Unit)
static func children_of_type(parent: Node, type: Variant) -> Array:
	var found: Array = []
	for child: Node in parent.get_children():
		if is_instance_of(child, type):
			found.append(child)
	return found
