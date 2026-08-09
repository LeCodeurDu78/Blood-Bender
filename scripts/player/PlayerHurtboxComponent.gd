extends HurtboxComponent
class_name PlayerHurtboxComponent

var shield_component: ShieldComponent


func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO, attacker: Node = null) -> bool:
	if shield_component != null:
		var resolution: Dictionary = shield_component.resolve_incoming_attack(attacker)
		if resolution.get("absorbed", false):
			return true

		var multiplier: float = resolution.get("damage_multiplier", 1.0)
		if multiplier <= 0.0:
			return true
		if multiplier != 1.0:
			amount *= multiplier

	return super.take_damage(amount, hit_position)