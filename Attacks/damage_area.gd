class_name DamageArea extends Area3D

var source_squad: Squad   # set at spawn
var attack: Attack        # set at spawn

func _on_body_entered(body: Node3D) -> void:
	var target: Squad = body as Squad
	if target == null or not is_instance_valid(source_squad):
		return
	source_squad.damage_dealt.emit(source_squad, attack, target)
