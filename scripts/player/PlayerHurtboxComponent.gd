extends HurtboxComponent
class_name PlayerHurtboxComponent

var shield_component: ShieldComponent
var doping_component: DopingManager


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

	if doping_component != null:
		amount *= doping_component.get_damage_taken_multiplier()

	return super.take_damage(amount, hit_position)


func apply_knockback(direction: Vector3, force: float) -> void:
	# Coagulant de Fer (Boost) : immunité aux poussées/knockback.
	if doping_component != null and doping_component.is_knockback_immune():
		return
	super.apply_knockback(direction, force)